require 'spec_helper'
require File.join(Rails.root, 'lib/cli/oacis_cli')

describe OacisCli do

  def at_temp_dir
    Dir.mktmpdir {|dir|
      Dir.chdir(dir) {
        yield
      }
    }
  end

  def create_simulator_id_json(simulator, path)
    File.open(path, 'w') {|io|
      io.puts( {"simulator_id" => simulator.id.to_s}.to_json )
      io.flush
    }
  end

  describe "#usage" do

    it "prints usage" do
      capture(:stdout) {
        OacisCli.new.invoke(:usage)
      }.should_not be_empty
    end
  end

  describe "#show_host" do

    before(:each) do
      @host = FactoryGirl.create(:host)
    end

    it "prints host information in json" do
      at_temp_dir {
        expected = [{
          "id" => @host.id.to_s,
          "name" => @host.name,
          "hostname" => @host.hostname,
          "user" => @host.user
        }]
        OacisCli.new.invoke(:show_host, [], {output: 'host.json'})
        File.exist?('host.json').should be_true
        JSON.load( File.read('host.json') ).should eq expected
      }
    end
  end

  describe "#simulator_template" do

    it "prints a template of simulator.json" do
      at_temp_dir {
        OacisCli.new.invoke(:simulator_template, [], {output: 'simulator.json'})
        File.exist?('simulator.json').should be_true
        expect {
          loaded = JSON.load(File.read('simulator.json'))
        }.not_to raise_error
      }
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
        sim.support_input_json.should be_true
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
        File.exist?('parameter_sets.json').should be_true
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
        loaded = JSON.load(File.read('parameter_sets.json')).should eq [parameters]
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
        mapped.should eq [ [10, 0.1], [20, 0.1], [30, 0.1], [10, 0.2], [20, 0.2], [30, 0.2]]
      }
    end

    it "outputs ids of parameter_sets in json" do
      at_temp_dir {
        invoke_create_parameter_sets
        File.exist?('parameter_set_ids.json').should be_true

        expected = @sim.reload.parameter_sets.map {|ps| {"parameter_set_id" => ps.id.to_s} }
        JSON.load(File.read('parameter_set_ids.json')).should eq expected
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
          loaded.should include(duplicated)
          loaded.should have(6).items
        }
      end
    end

    it "skips creation when an identical parameter_set exists"

    context "when host.json is specified" do
      it "sets executable_on_ids when host.json is specified"
    end
    context "when invalid json is given" do
      it "raises an exception"
    end
  end
end
