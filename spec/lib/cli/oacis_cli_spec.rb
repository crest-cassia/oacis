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

      it "sets executable_on_ids when host.json is specified" do
        at_temp_dir {
          OacisCli.new.invoke(:show_host, [], {output: 'host.json'})
          create_simulator_json('simulator.json')
          option = {input: 'simulator.json', output: 'simulator_id.json', host: 'host.json'}
          OacisCli.new.invoke(:create_simulator, [], option)

          Simulator.first.executable_on.should eq [@host]
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
end
