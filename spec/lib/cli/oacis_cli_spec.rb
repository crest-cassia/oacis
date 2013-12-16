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
          "support_input_json": false,
          "support_mpi": false,
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

    it "creates Simulator" do
      at_temp_dir {
        create_simulator_json('simulator.json')
        option = {input: 'simulator.json', output: 'simulator_id.json'}
        expect {
          OacisCli.new.invoke(:create_simulator, [], option)
        }.to change { Simulator.count }.by(1)
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
  end
end
