require 'spec_helper'
require File.join(Rails.root, 'lib/cli/oacis_cli')

describe OacisCli do

  def create_simulator_id_json(simulator, path)
    File.open(path, 'w') {|io|
      io.puts( {"simulator_id" => simulator.id.to_s}.to_json )
      io.flush
    }
  end

  describe "#parameter_sets_template" do

    before(:each) do
      @sim = FactoryGirl.create(:simulator, parameter_sets_count: 0)
    end

    it "outputs a template of parameter_sets.json" do
      at_temp_dir {
        create_simulator_id_json(@sim, 'simulator_id.json')
        option = {simulator: 'simulator_id.json', output: 'parameter_sets.json'}
        OacisCli.new.invoke(:parameter_sets_template, [], option)
        expect(File.exist?('parameter_sets.json')).to be_truthy
        expect {
          JSON.load(File.read('parameter_sets.json'))
        }.not_to raise_error
      }
    end

    it "outputs a template of parameters having default values" do
      at_temp_dir {
        create_simulator_id_json(@sim, 'simulator_id.json')
        option = {simulator: 'simulator_id.json', output: 'parameter_sets.json'}
        OacisCli.new.invoke(:parameter_sets_template, [], option)

        parameters = Hash[ @sim.parameter_definitions.map {|pd| [pd.key, pd.default]} ]
        expect(JSON.load(File.read('parameter_sets.json'))).to eq [parameters]
      }
    end

    context "when simulator_id.json is invalid" do

      def create_invalid_simulator_id_json(path)
        File.open(path, 'w') {|io|
          io.puts( {"simulator_id" => "INVALID"}.to_json )
          io.flush
        }
      end

      it "raises an exception" do
        at_temp_dir {
          create_invalid_simulator_id_json('simulator_id.json')
          option = {simulator: 'simulator_id.json', output: 'parameter_sets.json'}
          expect {
            OacisCli.new.invoke(:parameter_sets_template, [], option)
          }.to raise_error
        }
      end
    end

    context "when output file exists" do

      it "asks a question to overwrite the output file" do
        at_temp_dir {
          create_simulator_id_json(@sim, 'simulator_id.json')
          FileUtils.touch('parameter_sets.json')
          expect(Thor::LineEditor).to receive(:readline).with("Overwrite output file? ", :add_to_history => false).and_return("y")
          option = {simulator: 'simulator_id.json', output: 'parameter_sets.json'}
          OacisCli.new.invoke(:parameter_sets_template, [], option)
          expect(File.exist?('parameter_sets.json')).to be_truthy
          expect {
            JSON.load(File.read('parameter_sets.json'))
          }.not_to raise_error
        }
      end
    end

    context "with yes option when output file exists" do

      it "does not ask a question to overwrite the output file" do
        at_temp_dir {
          create_simulator_id_json(@sim, 'simulator_id.json')
          FileUtils.touch('parameter_sets.json')
          expect(Thor::LineEditor).not_to receive(:readline).with("Overwrite output file? ", :add_to_history => false)
          option = {simulator: 'simulator_id.json', output: 'parameter_sets.json', yes: true}
          OacisCli.new.invoke(:parameter_sets_template, [], option)
          expect(File.exist?('parameter_sets.json')).to be_truthy
          expect {
            JSON.load(File.read('parameter_sets.json'))
          }.not_to raise_error
        }
      end
    end
  end

  describe "#create_parameter_sets" do

    before(:each) do
      @sim = FactoryGirl.create(:simulator, parameter_sets_count: 0)
    end

    def create_parameter_sets_json(path)
      File.open(path, 'w') {|io|
        parameters = [
          {"L" => 10, "T" => 0.1},
          {"L" => 20, "T" => 0.1},
          {"L" => 30, "T" => 0.1},
          {"L" => 10, "T" => 0.2},
          {"L" => 20, "T" => 0.2},
          {"L" => 30, "T" => 0.2}
        ]
        io.puts parameters.to_json
      }
    end

    def invoke_create_parameter_sets
      create_simulator_id_json(@sim, 'simulator_id.json')
      create_parameter_sets_json('parameter_sets.json')
      option = {simulator: 'simulator_id.json', input: 'parameter_sets.json', output: "parameter_set_ids.json"}
      OacisCli.new.invoke(:create_parameter_sets, [], option)
    end

    it "creates a ParameterSet" do
      at_temp_dir {
        expect {
          invoke_create_parameter_sets
        }.to change { ParameterSet.count }.by(6)
      }
    end

    it "creates a ParameterSet having correct values" do
      at_temp_dir {
        invoke_create_parameter_sets
        mapped = @sim.reload.parameter_sets.map {|ps| [ps.v["L"], ps.v["T"]] }
        expect(mapped).to match_array([ [10, 0.1], [20, 0.1], [30, 0.1], [10, 0.2], [20, 0.2], [30, 0.2]])
      }
    end

    it "outputs ids of parameter_sets in json" do
      at_temp_dir {
        invoke_create_parameter_sets
        expect(File.exist?('parameter_set_ids.json')).to be_truthy

        expected = @sim.reload.parameter_sets.map {|ps| {"parameter_set_id" => ps.id.to_s} }
        expect(JSON.load(File.read('parameter_set_ids.json'))).to match_array(expected)
      }
    end

    context "when an identical parameter_set already exists" do

      before(:each) do
        @sim.parameter_sets.create(v: {"L" => 10, "T" => 0.1})
      end

      it "skips creation of duplicated parameter_set" do
        at_temp_dir {
          expect {
            invoke_create_parameter_sets
          }.to change { ParameterSet.count }.by(5)
        }
      end

      it "list of parameter_set_ids include ids of duplicated parameter_sets" do
        at_temp_dir {
          ps = @sim.parameter_sets.first
          invoke_create_parameter_sets

          duplicated = {"parameter_set_id" => ps.id.to_s}
          loaded = JSON.load(File.read('parameter_set_ids.json'))
          expect(loaded).to include(duplicated)
          expect(loaded.size).to eq 6
        }
      end

      it "duplicate ps is included even if given parameter is unordered" do
        at_temp_dir {
          ps = @sim.parameter_sets.first
          reversed = {"T" => 0.1, "L" => 10} # specify parameter in reverse order
          option = {simulator: @sim.id.to_s, input: reversed.to_json, output: "parameter_set_ids.json"}
          OacisCli.new.invoke(:create_parameter_sets, [], option)

          duplicated = {"parameter_set_id" => ps.id.to_s}
          loaded = JSON.load(File.read('parameter_set_ids.json'))
          expect(loaded).to include(duplicated)
          expect(loaded.size).to eq 1
        }
      end

      context "when Float parameter is given" do

        it "skips duplicate even when parameter is specified as integer" do
          at_temp_dir {
            ps = @sim.parameter_sets.create(v: {"L" => 10, "T" => 1.0})
            File.open('parameter_sets.json', 'w') {|io|
              io.puts [{"L" => 10, "T" => 1}].to_json
              io.flush
            }
            option = {simulator: @sim.id.to_s, input: 'parameter_sets.json', output: "parameter_set_ids.json"}
            expect {
              OacisCli.new.invoke(:create_parameter_sets, [], option)
            }.to_not change { @sim.parameter_sets.count }
          }
        end
      end
    end

    context "when PS with identical v exists under a different simulator" do

      before(:each) do
        s2 = FactoryGirl.create(:simulator, parameter_sets_count: 0, analyzers_count: 0)
        s2.parameter_sets.create(v: {"L" => 10, "T" => 0.1})
      end

      it "creates parameter sets" do
        at_temp_dir {
          expect {
            invoke_create_parameter_sets
          }.to change { @sim.parameter_sets.count }.by(6)
        }
      end
    end

    context "when input parameter_sets is specified as object" do

      def create_parameter_sets_json2(path)
        File.open(path, 'w') {|io|
          parameter_set_values = {"L" => [10,20], "T" => [0.1,0.2]}
          io.puts parameter_set_values.to_json
          io.flush
        }
      end

      it "creates ParameterSets" do
        at_temp_dir {
          create_simulator_id_json(@sim, 'simulator_id.json')
          create_parameter_sets_json2('parameter_sets.json')
          option = {simulator: 'simulator_id.json', input: 'parameter_sets.json', output: "parameter_set_ids.json"}
          expect {
            OacisCli.new.invoke(:create_parameter_sets, [], option)
          }.to change { @sim.parameter_sets.count }.by(4)
        }
      end
    end

    context "when input parameter sets is given not by file but by json-string" do

      it "creates parameter sets" do
        at_temp_dir {
          create_simulator_id_json(@sim, 'simulator_id.json')
          option = {simulator: 'simulator_id.json', input: '{"L":[10,20],"T":[1.0,2.0]}', output: "parameter_set_ids.json"}
          expect {
            OacisCli.new.invoke(:create_parameter_sets, [], option)
          }.to change { @sim.parameter_sets.count }.by(4)
        }
      end
    end

    context "when run option is given" do

      before(:each) do
        @host = FactoryGirl.create(:host_with_parameters)
        @sim.executable_on.push @host
        @sim.save!
      end

      it "creates both parameter sets and runs with host parameters" do
        at_temp_dir {
          input = {"L" => [0,1], "T" => [1.0,2.0]}
          run_param = {
            "num_runs" => 3, "host_id" => @host.id.to_s,
            "host_parameters" => {"param1" => "XXX", "param2" => "YYY"}
          }
          option = {simulator: @sim.id.to_s, input: input.to_json,
            output: "parameter_set_ids.json", run: run_param.to_json}

          expect {
            OacisCli.new.invoke(:create_parameter_sets, [], option)
            }.to change { @sim.runs.count }.by(12)

          expect(@sim.reload.runs.last.host_parameters).to eq run_param["host_parameters"]
        }
      end

      it "creates runs for existing ps" do
        @ps = FactoryGirl.create(:parameter_set,
                                 simulator: @sim,
                                 v: {"L" => 1, "T" => 1.0},
                                 runs_count: 1,
                                 finished_runs_count: 0
                                 )
        at_temp_dir {
          input = {"L" => [0,1], "T" => 1.0}
          run_param = {
            "num_runs" => 2, "host_id" => @host.id.to_s,
            "host_parameters" => {"param1" => "XXX", "param2" => "YYY"}
          }
          option = {simulator: @sim.id.to_s, input: input.to_json,
            output: "parameter_set_ids.json", run: run_param.to_json}

          expect {
            OacisCli.new.invoke(:create_parameter_sets, [], option)
          }.to change { @sim.runs.count }.by(3)
        }
      end
    end

    context "when simulator.json is invalid" do

      it "raises an exception when simulator.json is not found" do
        at_temp_dir {
          create_parameter_sets_json('parameter_sets.json')
          option = {simulator: 'simulator_id.json', input: 'parameter_sets.json', output: "parameter_set_ids.json"}
          expect {
            OacisCli.new.invoke(:create_parameter_sets, [], option)
          }.to raise_error
        }
      end

      def create_invalid_simulator_json(simulator, path)
        File.open(path, 'w') {|io|
          io.puts( {"simulator_id" => "DO_NOT_EXIST"}.to_json )
          io.flush
        }
      end

      it "raises an exception when the format of simulator.json is invalid" do
        at_temp_dir {
          create_invalid_simulator_json(@sim, 'simulator_id.json')
          create_parameter_sets_json('parameter_sets.json')
          option = {simulator: 'simulator_id.json', input: 'parameter_sets.json', output: "parameter_set_ids.json"}
          expect {
            OacisCli.new.invoke(:create_parameter_sets, [], option)
          }.to raise_error
        }
      end
    end

    context "when parameter_sets.json is invalid" do

      def create_invalid_parameter_sets_json(path)
        File.open(path, 'w') {|io|
          parameter_set_values = [
            {"L" => 10, "T" => 0.1},
            {"L" => 20, "T" => 0.1},
            {"L" => 10, "T" => "XXX"}
          ]
          io.puts parameter_set_values.to_json
          io.flush
        }
      end

      def invoke_create_parameter_sets_with_invalid_parameter_sets_json
        create_simulator_id_json(@sim, 'simulator_id.json')
        create_invalid_parameter_sets_json('parameter_sets.json')
        option = {simulator: 'simulator_id.json', input: 'parameter_sets.json', output: "parameter_set_ids.json"}
        OacisCli.new.invoke(:create_parameter_sets, [], option)
      end

      it "raises an exception" do
        at_temp_dir {
          expect {
            invoke_create_parameter_sets_with_invalid_parameter_sets_json
          }.to raise_error
        }
      end
    end

    context "when output file exists" do

      it "asks a question to overwrite the output file" do
        at_temp_dir {
          FileUtils.touch('parameter_set_ids.json')
          expect(Thor::LineEditor).to receive(:readline).with("Overwrite output file? ", :add_to_history => false).and_return("y")
          invoke_create_parameter_sets
        }
      end
    end

    context "with yes option when output file exists" do

      it "does not ask a question to overwrite the output file" do
        at_temp_dir {
          FileUtils.touch('parameter_set_ids.json')
          expect(Thor::LineEditor).not_to receive(:readline).with("Overwrite output file? ", :add_to_history => false)
          create_simulator_id_json(@sim, 'simulator_id.json')
          create_parameter_sets_json('parameter_sets.json')
          option = {simulator: 'simulator_id.json', input: 'parameter_sets.json', output: "parameter_set_ids.json", yes: true}
          OacisCli.new.invoke(:create_parameter_sets, [], option)
          expect(File.exist?('parameter_set_ids.json')).to be_truthy
          expect {
            JSON.load(File.read('parameter_set_ids.json'))
          }.not_to raise_error
        }
      end
    end
  end
end

