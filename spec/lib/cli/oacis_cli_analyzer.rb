require 'spec_helper'
require File.join(Rails.root, 'lib/cli/oacis_cli')

describe OacisCli do

  describe "#analyzer_template" do

    it "prints a template of analyzer.json" do
      at_temp_dir {
        OacisCli.new.invoke(:analyzer_template, [], {output: 'analyzer.json'})
        expect(File.exist?('analyzer.json')).to be_truthy
        expect {
          JSON.load(File.read('analyzer.json'))
        }.not_to raise_error
      }
    end

    context "when output file exists" do

      it "ask a question to overwrite the output file" do
        at_temp_dir {
          FileUtils.touch('analyzer.json')
          expect(Thor::LineEditor).to receive(:readline).with("Overwrite output file? ", :add_to_history => false).and_return("y")
          OacisCli.new.invoke(:analyzer_template, [], {output: 'analyzer.json'})
        }
      end
    end

    context "with yes option when output file exists" do

      it "does not ask a question to overwrite the output file" do
        at_temp_dir {
          FileUtils.touch('analyzer.json')
          expect(Thor::LineEditor).not_to receive(:readline).with("Overwrite output file? ", :add_to_history => false)
          OacisCli.new.invoke(:analyzer_template, [], {output: 'analyzer.json', yes: true})
          expect(File.exist?('analyzer.json')).to be_truthy
          expect {
            JSON.load(File.read('analyzer.json'))
          }.not_to raise_error
        }
      end
    end
  end

  describe "#create_analyzer" do

    before(:each) do
      @sim=FactoryGirl.create(:simulator, analyzers_count: 0, analyzers_on_parameter_set_count: 0)
      @host=@sim.executable_on.first
    end

    def create_analyzer_json(path)
      io = File.open(path, 'w')
      io.puts <<-EOS
        {
          "name": "a_sample_analyzer",
          "type": "on_run",
          "auto_run": "no",
          "files_to_copy": "*",
          "description": "",
          "command": "/path/to/analyzer.out",
          "support_input_json": true,
          "support_mpi": false,
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

    it "creates an Analyzer" do
      at_temp_dir {
        create_analyzer_json('analyzer.json')
        option = {simulator: @sim.id.to_s, input: 'analyzer.json', output: 'analyzer_id.json'}
        expect {
          OacisCli.new.invoke(:create_analyzer, [], option)
        }.to change { Analyzer.count }.by(1)
      }
    end

    it "creates an Analyzer having correct attributes" do
      at_temp_dir {
        create_analyzer_json('analyzer.json')
        option = {simulator: @sim.id.to_s, input: 'analyzer.json', output: 'analyzer_id.json'}
        OacisCli.new.invoke(:create_analyzer, [], option)

        anz = Analyzer.order_by(id: :asc).last
        expect(anz.name).to eq "a_sample_analyzer"
        expect(anz.support_input_json).to be_truthy
        expect(anz.pre_process_script).to be_nil
        expect(anz.type).to eq :on_run
        expect(anz.auto_run).to eq :no
      }
    end

    it "creates an Analyzer having correct parameter_definitions" do
      at_temp_dir {
        create_analyzer_json('analyzer.json')
        option = {simulator: @sim.id.to_s, input: 'analyzer.json', output: 'analyzer_id.json'}
        OacisCli.new.invoke(:create_analyzer, [], option)

        expected = [
          ["p1", "Integer", 0, "parameter1"],
          ["p2", "Float", 5.0, "parameter2"]
        ]
        expect(Analyzer.order_by(id: :asc).last.parameter_definitions.map { |pd|
          [pd.key, pd.type, pd.default, pd.description]
        }).to eq expected
      }
    end

    it "outputs created analyzer id in json" do
      at_temp_dir {
        create_analyzer_json('analyzer.json')
        option = {simulator: @sim.id.to_s, input: 'analyzer.json', output: 'analyzer_id.json'}
        OacisCli.new.invoke(:create_analyzer, [], option)

        expected = { "analyzer_id" => Analyzer.order_by(id: :asc).last.id.to_s }
        output = JSON.parse(File.read('analyzer_id.json'))
        expect(output).to eq expected
      }
    end

    context "when host.json is specified" do

      def create_analyzer_with_host_json
        OacisCli.new.invoke(:show_host, [], {output: 'host.json'})
        create_analyzer_json('analyzer.json')
        option = {simulator: @sim.id.to_s, input: 'analyzer.json', output: 'analyzer_id.json', host: 'host.json'}
        OacisCli.new.invoke(:create_analyzer, [], option)
      end

      it "sets executable_on_ids when host.json is specified" do
        at_temp_dir {
          create_analyzer_with_host_json
          expect(Analyzer.order_by(id: :asc).last.executable_on).to include(@host)
          expect(Analyzer.order_by(id: :asc).last.auto_run_submitted_to).to eq @host
        }
      end

      it "sets Host#executable_simulators field" do
        at_temp_dir {
          create_analyzer_with_host_json
          expect(@host.reload.executable_analyzers).to eq [Analyzer.order_by(id: :asc).last]
        }
      end
    end

    context "when invalid json is given" do

      it "raises an exception" do
        at_temp_dir {
          File.open('analyzer.json', 'w') {|io|
            io.puts "{\"name\": \"invalid analyzer\" }"
            io.flush
          }
          option = {simulator: @sim.id.to_s, input: 'analyzer.json', output: 'analyzer_id.json'}
          expect {
            OacisCli.new.invoke(:create_analyzer, [], option)
          }.to raise_error
        }
      end
    end

    context "when output file exists" do

      it "asks a question to overwrite the output file" do
        at_temp_dir {
          FileUtils.touch("analyzer_id.json")
          expect(Thor::LineEditor).to receive(:readline).with("Overwrite output file? ", :add_to_history => false).and_return("y")
          create_analyzer_json('analyzer.json')
          option = {simulator: @sim.id.to_s, input: 'analyzer.json', output: 'analyzer_id.json'}
          OacisCli.new.invoke(:create_analyzer, [], option)
        }
      end
    end

    context "with yes option when output file exists" do

      it "does not ask a question to overwrite the output file" do
        at_temp_dir {
          FileUtils.touch("analyzer_id.json")
          expect(Thor::LineEditor).not_to receive(:readline).with("Overwrite output file? ", :add_to_history => false)
          create_analyzer_json('analyzer.json')
          option = {simulator: @sim.id.to_s, input: 'analyzer.json', output: 'analyzer_id.json', yes: true}
          expect {
            OacisCli.new.invoke(:create_analyzer, [], option)
          }.to change { Analyzer.count }.by(1)
          expect(File.exist?('analyzer_id.json')).to be_truthy
        }
      end
    end
  end
end
