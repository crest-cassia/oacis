require 'spec_helper'
require File.join(Rails.root, 'lib/cli/oacis_cli')

describe OacisCli do

  describe "#simulator_template" do

    it "prints a template of simulator.json" do
      at_temp_dir {
        OacisCli.new.invoke(:simulator_template, [], {output: 'simulator.json'})
        File.exist?('simulator.json').should be_truthy
        expect {
          loaded = JSON.load(File.read('simulator.json'))
        }.not_to raise_error
      }
    end

    context "when dry_run option is specified" do

      it "does not create output file" do
        at_temp_dir {
          OacisCli.new.invoke(:simulator_template, [], {output: 'simulator.json', dry_run: true})
          File.exist?('simulator.json').should be_falsey
        }
      end
    end

    context "when output file exists" do

      it "ask a question to overwrite the output file" do
        at_temp_dir {
          FileUtils.touch('simulator.json')
          expect(Thor::LineEditor).to receive(:readline).with("Overwrite output file? ", :add_to_history => false).and_return("y")
          OacisCli.new.invoke(:simulator_template, [], {output: 'simulator.json'})
        }
      end
    end

    context "with yes option when output file exists" do

      it "does not ask a question to overwrite the output file" do
        at_temp_dir {
          FileUtils.touch('simulator.json')
          expect(Thor::LineEditor).not_to receive(:readline).with("Overwrite output file? ", :add_to_history => false)
          OacisCli.new.invoke(:simulator_template, [], {output: 'simulator.json', yes: true})
          File.exist?('simulator.json').should be_truthy
          expect {
            JSON.load(File.read('simulator.json'))
          }.not_to raise_error
        }
      end
    end
  end

  describe "#create_simulator" do

    def create_simulator_json(path)
      io = File.open(path, 'w')
      io.puts <<-EOS
        {
          "name": "a_sample_simulator",
          "command": "/path/to/simulator.out",
          "support_input_json": true,
          "support_mpi": true,
          "support_omp": false,
          "print_version_command": null,
          "pre_process_script": null,
          "executable_on_ids": [],
          "parameter_definitions": [
            {"key": "p1","type": "Integer","default": 0,"description": "parameter1"},
            {"key": "p2","type": "Float","default": 5.0,"description": "parameter2"}
          ]
        }
      EOS
      io.flush
    end

    it "creates a Simulator" do
      at_temp_dir {
        create_simulator_json('simulator.json')
        option = {input: 'simulator.json', output: 'simulator_id.json'}
        expect {
          OacisCli.new.invoke(:create_simulator, [], option)
        }.to change { Simulator.count }.by(1)
      }
    end

    it "creates a Simulator having correct attributes" do
      at_temp_dir {
        create_simulator_json('simulator.json')
        option = {input: 'simulator.json', output: 'simulator_id.json'}
        OacisCli.new.invoke(:create_simulator, [], option)

        sim = Simulator.first
        sim.name.should eq "a_sample_simulator"
        sim.support_input_json.should be_truthy
        sim.pre_process_script.should be_nil
      }
    end

    it "creates a Simulator having correct parameter_definitions" do
      at_temp_dir {
        create_simulator_json('simulator.json')
        option = {input: 'simulator.json', output: 'simulator_id.json'}
        OacisCli.new.invoke(:create_simulator, [], option)

        expected = [
          ["p1", "Integer", 0, "parameter1"],
          ["p2", "Float", 5.0, "parameter2"]
        ]
        Simulator.first.parameter_definitions.map { |pd|
          [pd.key, pd.type, pd.default, pd.description]
        }.should eq expected
      }
    end

    it "outputs created simulator id in json" do
      at_temp_dir {
        create_simulator_json('simulator.json')
        option = {input: 'simulator.json', output: 'simulator_id.json'}
        OacisCli.new.invoke(:create_simulator, [], option)

        expected = { "simulator_id" => Simulator.first.id.to_s }
        output = JSON.parse(File.read('simulator_id.json'))
        output.should eq expected
      }
    end

    context "when host.json is specified" do

      before(:each) do
        @host = FactoryGirl.create(:host)
      end

      def create_simulator_with_host_json
        OacisCli.new.invoke(:show_host, [], {output: 'host.json'})
        create_simulator_json('simulator.json')
        option = {input: 'simulator.json', output: 'simulator_id.json', host: 'host.json'}
        OacisCli.new.invoke(:create_simulator, [], option)
      end

      it "sets executable_on_ids when host.json is specified" do
        at_temp_dir {
          create_simulator_with_host_json
          Simulator.first.executable_on.should eq [@host]
        }
      end

      it "sets Host#executable_simulators field" do
        at_temp_dir {
          create_simulator_with_host_json
          @host.reload.executable_simulators.should eq [Simulator.first]
        }
      end
    end

    context "when invalid json is given" do

      it "raises an exception" do
        at_temp_dir {
          File.open('simulator.json', 'w') {|io|
            io.puts "{\"name\": \"invalid simulator\" }"
            io.flush
          }
          option = {input: 'simulator.json', output: 'simulator_id.json'}
          expect {
            OacisCli.new.invoke(:create_simulator, [], option)
          }.to raise_error
        }
      end
    end

    context "when dry_run option is specified" do

      def invoke_create_simulator_with_dry_run
        create_simulator_json('simulator.json')
        option = {input: 'simulator.json', output: 'simulator_id.json', dry_run: true}
        OacisCli.new.invoke(:create_simulator, [], option)
      end

      it "does not create Simulator" do
        at_temp_dir {
          expect {
            invoke_create_simulator_with_dry_run
          }.not_to change { Simulator.count }
        }
      end

      it "does not create output file" do
        at_temp_dir {
          invoke_create_simulator_with_dry_run
          File.exist?('simulator_id.json').should be_falsey
        }
      end
    end

    context "when output file exists" do

      it "asks a question to overwrite the output file" do
        at_temp_dir {
          FileUtils.touch("simulator_id.json")
          expect(Thor::LineEditor).to receive(:readline).with("Overwrite output file? ", :add_to_history => false).and_return("y")
          create_simulator_json('simulator.json')
          option = {input: 'simulator.json', output: 'simulator_id.json'}
          OacisCli.new.invoke(:create_simulator, [], option)
        }
      end
    end

    context "with yes option when output file exists" do

      it "does not ask a question to overwrite the output file" do
        at_temp_dir {
          FileUtils.touch("simulator_id.json")
          expect(Thor::LineEditor).not_to receive(:readline).with("Overwrite output file? ", :add_to_history => false)
          create_simulator_json('simulator.json')
          option = {input: 'simulator.json', output: 'simulator_id.json', yes: true}
          expect {
            OacisCli.new.invoke(:create_simulator, [], option)
          }.to change { Simulator.count }.by(1)
          File.exist?('simulator_id.json').should be_truthy
        }
      end
    end
  end

  describe "#append_parameter_definition" do

    before(:each) do
      @sim = FactoryGirl.create(:simulator, parameter_sets_count: 3)
    end

    it "append a new parameter definition to the simulator" do
      at_temp_dir {
        option = {simulator: @sim.id.to_s, name: 'NEW_PARAM', type: "Float", default: 0.5}
        OacisCli.new.invoke(:append_parameter_definition, [], option)
        @sim.reload
        expect(@sim.parameter_definitions.size).to eq 3
        new_param_def = @sim.parameter_definitions.last
        new_param_def.key.should eq "NEW_PARAM"
        new_param_def.type.should eq "Float"
        new_param_def.default.should eq 0.5
      }
    end

    it "updates the existing parameter sets so as to have the new parameter key with the default value" do
      at_temp_dir {
        option = {simulator: @sim.id.to_s, name: 'NEW_PARAM', type: "Float", default: 0.5}
        OacisCli.new.invoke(:append_parameter_definition, [], option)
        @sim.reload.parameter_sets.all? do |ps|
          ps.v["NEW_PARAM"].should eq 0.5
        end
      }
    end

    it "adds Boolean parameter correctly" do
      at_temp_dir {
        option = {simulator: @sim.id.to_s, name: "NEW_PARAM", type: "Boolean", default: false}
        OacisCli.new.invoke(:append_parameter_definition, [], option)
        new_param_def = @sim.reload.parameter_definitions.last
        new_param_def.default.should eq false
      }
    end

    describe "error case" do

      context "when invalid simulator ID is given" do

        it "throws an exception" do
          at_temp_dir {
            option = {simulator: "INVALID", name: 'NEW_PARAM', type: "Float", default: 0.5}
            expect {
              OacisCli.new.invoke(:append_parameter_definition, [], option)
            }.to raise_error
          }
        end
      end

      context "when name is duplicated" do

        it "throws an exception" do
          at_temp_dir {
            option = {simulator: @sim.id.to_s, name: 'L', type: "Float", default: 0.5}
            expect {
              OacisCli.new.invoke(:append_parameter_definition, [], option)
            }.to raise_error
          }
        end
      end

      context "when name is invalid" do

        it "throws an exception" do
          at_temp_dir {
            option = {simulator: @sim.id.to_s, name: 'L', type: "Float", default: 0.5}
            expect {
              OacisCli.new.invoke(:append_parameter_definition, [], option)
            }.to raise_error
          }
        end
      end

      context "when type is neither 'Integer', 'Float', 'String', nor 'Boolean'" do

        it "throws an exception" do
          at_temp_dir {
            option = {simulator: @sim.id.to_s, name: 'L', type: "Double", default: 0.5}
            expect {
              OacisCli.new.invoke(:append_parameter_definition, [], option)
            }.to raise_error
          }
        end
      end

      context "when default value is not compatible with the type" do

        it "throws an exception" do
          at_temp_dir {
            option = {simulator: @sim.id.to_s, name: 'L', type: "Integer", default: 0.5}
            expect {
              OacisCli.new.invoke(:append_parameter_definition, [], option)
            }.to raise_error
          }
        end
      end
    end
  end
end
