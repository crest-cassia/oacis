require 'spec_helper'
require File.join(Rails.root, 'lib/cli/oacis_cli')

describe OacisCli do

  before(:each) do
    @host = FactoryGirl.create(:host_with_parameters)
    @sim = FactoryGirl.create(:simulator, parameter_sets_count: 2, runs_count: 0,
                              finished_runs_count: 2,
                              analyzers_count: 1, run_analysis: false,
                              analyzers_on_parameter_set_count: 1,
                              run_analysis_on_parameter_set: false)
    @sim.analyzers.each do |azr|
      azr.update_attribute(:support_mpi, true)
      azr.update_attribute(:support_omp, true)
    end
  end

  def invoke_create_analyses(type, option={})
    case type
    when :on_run
      analyzer_id = @sim.analyzers.where(type: :on_run).first.id.to_s
    when :on_parameter_set
      analyzer_id = @sim.analyzers.where(type: :on_parameter_set).first.id.to_s
    end
    options = { analyzer_id: analyzer_id, input: 'azr_parameters.json',
                output: 'analysis_ids.json'}
    options.merge!(option)
    OacisCli.new.invoke(:analyses_template, [], {analyzer_id: analyzer_id, output: "azr_parameters.json"})
    OacisCli.new.invoke(:create_analyses, [], options)
  end

  describe "#analyses_template" do

    it "outputs a template of analyses" do
      at_temp_dir {
        options = { analyzer_id: @sim.analyzers.first.id.to_s, output: 'anz_parameters.json' }
        OacisCli.new.invoke(:analyses_template, [], options)
        expect(File.exist?('anz_parameters.json')).to be_truthy
        expect {
          JSON.load(File.read('anz_parameters.json'))
        }.not_to raise_error
      }
    end

    it "outputs a template having default analysis parameters" do
      at_temp_dir {
        options = { analyzer_id: @sim.analyzers.first.id.to_s, output: 'anz_parameters.json' }
        OacisCli.new.invoke(:analyses_template, [], options)
        expected = @sim.analyzers.first.parameter_definitions.map {|pdef| [pdef["key"], pdef["default"]] }
        expect(JSON.load(File.read('anz_parameters.json'))).to eq [Hash[expected]]
      }
    end

    it "when analyzer id is invalid" do
      at_temp_dir {
        options = { analyzer_id: "DO_NOT_EXIST", output: 'analyzers.json' }
        expect {
          OacisCli.new.invoke(:analyses_template, [], options)
        }.to raise_error
      }
    end

    context "when dry_run option is specified" do

      it "does not create output file" do
        at_temp_dir {
          options = { analyzer_id: @sim.analyzers.first.id.to_s, output: 'analyzres.json', dry_run: true }
          OacisCli.new.invoke(:analyses_template, [], options)
          expect(File.exist?('analyzers.json')).to be_falsey
        }
      end
    end

    context "when output file exists" do

      it "asks a question to overwrite the output file" do
        at_temp_dir {
          options = { analyzer_id: @sim.analyzers.first.id.to_s, output: 'anz_parameters.json' }
          FileUtils.touch(options[:output])
          expect(Thor::LineEditor).to receive(:readline).with("Overwrite output file? ", :add_to_history => false).and_return("y")
          OacisCli.new.invoke(:analyses_template, [], options)
        }
      end
    end

    context "with yes option when output file exists" do

      it "does not ask a question to overwrite the output file" do
        at_temp_dir {
          options = { analyzer_id: @sim.analyzers.first.id.to_s, output: 'anz_parameters.json', yes: true}
          FileUtils.touch(options[:output])
          expect(Thor::LineEditor).not_to receive(:readline).with("Overwrite output file? ", :add_to_history => false)
          OacisCli.new.invoke(:analyses_template, [], options)
          expected = @sim.analyzers.first.parameter_definitions.map {|pdef| [pdef["key"], pdef["default"]] }
          expect(JSON.load(File.read('anz_parameters.json'))).to eq [Hash[expected]]
        }
      end
    end
  end

  describe "#create_analyses" do

    it "creates analyses on finished runs" do
      at_temp_dir {
        expect {
          invoke_create_analyses(:on_run)
        }.to change { Analysis.where(analyzable_type: "Run").count }.by(4)
      }
    end

    it "creates analyses on parameter_sets" do
      at_temp_dir {
        expect {
          invoke_create_analyses(:on_parameter_set)
        }.to change { Analysis.where(analyzable_type: "ParameterSet").count }.by(2)
      }
    end

    it "do not create analyses on parameter_sets without having :finished runs" do
      at_temp_dir {
        expect {
          @sim.parameter_sets.first.runs.each do |run|
            run.status = :failed
            run.save!
          end
          invoke_create_analyses(:on_parameter_set)
        }.to change { Analysis.where(analyzable_type: "ParameterSet").count }.by(1)

      }
    end

    it "outputs ids of created analyses in json" do
      at_temp_dir {
        invoke_create_analyses(:on_run, {output: 'analysis_ids_tmp.json'})

        expect(File.exist?('analysis_ids_tmp.json')).to be_truthy
        expected = Analysis.all.map {|anl| {"analysis_id" => anl.id.to_s} }.sort_by {|h| h["analysis_id"]}
        expect(JSON.load(File.read('analysis_ids_tmp.json'))).to match_array(expected)
      }
    end

    context "when :target option exists" do

      it "creates analyses on :runs" do
        at_temp_dir {
          expect {
            io = File.open('runs.json','w')
            a = []
            @sim.parameter_sets.each do |ps|
              h = {"run_id" => ps.runs.first.id.to_s }
              a << h
            end
            io.puts a.to_json
            io.close
            invoke_create_analyses(:on_run, {target: "runs.json"})
          }.to change { Analysis.where(analyzable_type: "Run").count }.by(2)
        }
      end

      it "creates analyses on :parameter_sets" do
        at_temp_dir {
          expect {
            io = File.open('parameter_sets.json','w')
            a = [{"parameter_set_id" => @sim.parameter_sets.first.id.to_s }]
            io.puts a.to_json
            io.close
            invoke_create_analyses(:on_parameter_set, {target: "parameter_sets.json"})
          }.to change { Analysis.where(analyzable_type: "ParameterSet").count }.by(1)
        }
      end
    end

    context "when :first_run_only option exists" do

      describe "creates analyses only on the first_run of each parameter_sets" do
        subject { -> {
                       at_temp_dir {
                         invoke_create_analyses(:on_run, {first_run_only: "first_run_only"})
                       }
                     }
        }
        it { is_expected.to change { Analysis.count }.by(2) }
        it { is_expected.to change { Analysis.where(parameter_set_id: @sim.parameter_sets.first.id.to_s).count }.by(1) }
      end
    end

    context "when analyses exists" do

      before(:each) do
        at_temp_dir {
          invoke_create_analyses(:on_run, {first_run_only: "first_run_only"})
        }
      end

      it "iterates creation of analyses on runs without same analyzer and analyzers parameter" do
        at_temp_dir {
          expect {
            invoke_create_analyses(:on_run, {})
          }.to change { Analysis.count }.by(2)
        }
      end

      it "outputs ids of created and existing analyses" do
        at_temp_dir {
          invoke_create_analyses(:on_run, {output: "analysis_ids_tmp.json"})

          expect(File.exist?('analysis_ids_tmp.json')).to be_truthy
          expected = Analysis.all.map {|anl| {"analysis_id" => anl.id.to_s} }.sort_by {|h| h["analysis_id"]}
          expect(JSON.load(File.read('analysis_ids_tmp.json'))).to match_array(expected)
        }
      end
    end

    context "when dry_run option is given" do

      it "does not save Anasyses" do
        at_temp_dir {
          expect {
            invoke_create_analyses(:on_run, {dry_run: true})
          }.to_not change { Analysis.count }
        }
      end

      it "does not create output file" do
        at_temp_dir {
          invoke_create_analyses(:on_run, {output: "analysis_ids_dry_run.json", dry_run: true})
          expect(File.exist?('analysis_ids_dry_run.json')).to be_falsey
        }
      end
    end

    context "when both target option and first_run_only option are given" do

      it "raise an error" do
        at_temp_dir {
          options = { target: "some thing", first_run_only: "first_run_only"}
          expect {
            invoke_create_analyses(:on_run, options)
          }.to raise_error
        }
      end
    end

    context "when input is not given" do

      it "creates analyses with default analsis parameters" do
        at_temp_dir {
          expect {
            invoke_create_analyses(:on_run)
          }.to change { Analysis.where(analyzable_type: "Run").count }.by(4)
        }
        expected = @sim.analyzers.first.parameter_definitions.map {|pdef| [pdef["key"], pdef["default"]] }
        expect(Analysis.first.parameters).to eq Hash[expected]
      end
    end

    context "when output file exists" do

      it "asks a question to overwrite the output file" do
        at_temp_dir {
          FileUtils.touch("analysis_ids_tmp.json")
          expect(Thor::LineEditor).to receive(:readline).with("Overwrite output file? ", :add_to_history => false).and_return("y")
          invoke_create_analyses(:on_run, {output: "analysis_ids_tmp.json"})
        }
      end
    end

    context "with yes option when output file exists" do

      it "does not ask a question to overwrite the output file" do
        at_temp_dir {
          FileUtils.touch("analysis_ids_tmp.json")
          expect(Thor::LineEditor).not_to receive(:readline).with("Overwrite output file? ", :add_to_history => false)
          invoke_create_analyses(:on_run, {output: "analysis_ids_tmp.json", yes: true})
          expect(File.exist?('analysis_ids_tmp.json')).to be_truthy
          expected = Analysis.all.map {|anl| {"analysis_id" => anl.id.to_s} }.sort_by {|h| h["analysis_id"]}
          expect(JSON.load(File.read('analysis_ids_tmp.json'))).to match_array(expected)
        }
      end
    end
  end

  describe "#analysis_status" do

    it "shows number of analysis for each status in json" do
      at_temp_dir {
        invoke_create_analyses(:on_run, {output: "analysis_ids.json"})
        options = {analysis_ids: 'analysis_ids.json'}
        expect {
          OacisCli.new.invoke(:analysis_status, [], options)
        }.to output(JSON.pretty_generate({total: 4, created: 4, running: 0, failed: 0, finished: 0})+"\n").to_stdout
      }
    end
  end

  describe "#destroy_analyses" do

    it "destroys analyses specified by 'status'" do
      analyzer_id = @sim.analyzers.where(type: :on_run).first.id.to_s
      at_temp_dir {
        invoke_create_analyses(:on_run, {output: "analysis_ids.json"})
        Analysis.limit(3).each do |anl|
          anl.status = :failed
          anl.save
        end
        options = {analyzer_id: analyzer_id, query: {"status" => "failed"}, yes: true}
        expect {
          OacisCli.new.invoke(:destroy_analyses, [], options)
        }.to change { Analysis.where(status: :failed).count }.by(-3)
      }
    end

    it "destroys analyses specified by 'analyzer_version'" do
      analyzer_id = @sim.analyzers.where(type: :on_run).first.id.to_s
      at_temp_dir {
        invoke_create_analyses(:on_run, {output: "analysis_ids.json"})
        Analysis.limit(3).each do |anl|
          anl.update_attribute(:status, :finished)
          anl.update_attribute(:analyzer_version, "v0.1.0")
        end
        options = {analyzer_id: analyzer_id, query: {"analyzer_version" => "v0.1.0"}, yes: true}
        expect {
          OacisCli.new.invoke(:destroy_analyses, [], options)
        }.to change { Analysis.where(analyzer_version: "v0.1.0").count }.by(-3)
      }
    end

    it "destroys analyses of analyzer_version=nil when analyzer_version is empty" do
      analyzer_id = @sim.analyzers.where(type: :on_run).first.id.to_s
      at_temp_dir {
        invoke_create_analyses(:on_run, {output: "analysis_ids.json"})
        Analysis.each do |anl|
          anl.update_attribute(:status, :finished)
        end
        Analysis.limit(2).each do |anl|
          anl.update_attribute(:analyzer_version, "v0.1.0")
        end
        options = {analyzer_id: analyzer_id, query: {"analyzer_version" => ""}, yes: true}
        specified_analyses_count = Analysis.where(analyzer_version: nil).count
        expect {
          OacisCli.new.invoke(:destroy_analyses, [], options)
        }.to change { Analysis.where(analyzer_version: nil).count }.by(-specified_analyses_count)
      }
    end

    context "when query option is invalid" do
      it "raises an exception" do
        analyzer_id = @sim.analyzers.where(type: :on_run).first.id.to_s
        at_temp_dir {
          invoke_create_analyses(:on_run, {output: "analysis_ids.json"})
          options = {analyzer_id: analyzer_id, query: "DO_NOT_EXIST", yes: true}
          expect {
            $stdout = StringIO.new # set new string stream not to write Thor#say message on test result
            OacisCli.new.invoke(:destroy_analyses, [], options)
            $stdout = STDOUT
          }.to raise_error
          options = {analyzer_id: analyzer_id, query: { "status" => "DO_NOT_EXIST" }, yes: true}
          expect {
            OacisCli.new.invoke(:destroy_analyses, [], options)
          }.to raise_error
          options = {analyzer_id: analyzer_id, query: { "analyzer_version" => "DO_NOT_EXIST" }, yes: true}
          expect {
            OacisCli.new.invoke(:destroy_analyses, [], options)
          }.to raise_error
        }
      end
    end

    context "if user say \"no\" not to destroy analyses" do

      it "destroys nothing" do
        analyzer_id = @sim.analyzers.where(type: :on_run).first.id.to_s
        at_temp_dir {
          invoke_create_analyses(:on_run, {output: "analysis_ids.json"})
          Analysis.each do |anl|
            anl.update_attribute(:status, :finished)
          end
          Analysis.limit(2).each do |anl|
            anl.update_attribute(:analyzer_version, "v0.1.0")
          end
          expect(Thor::LineEditor).to receive(:readline).with("Destroy 2 analyses? ", :add_to_history => false).and_return("n")
          options = {analyzer_id: analyzer_id, query: {"analyzer_version" => "v0.1.0"}}
          expect {
            OacisCli.new.invoke(:destroy_analyses, [], options)
          }.not_to change { Analysis.where(analyzer_version: "v0.1.0").count }
        }
      end
    end

    context "with yes option" do

      it "destroys analyses without confirmation" do
        analyzer_id = @sim.analyzers.where(type: :on_run).first.id.to_s
        at_temp_dir {
          invoke_create_analyses(:on_run, {output: "analysis_ids.json"})
          Analysis.each do |anl|
            anl.update_attribute(:status, :finished)
          end
          Analysis.limit(2).each do |anl|
            anl.update_attribute(:analyzer_version, "v0.1.0")
          end
          expect(Thor::LineEditor).not_to receive(:readline).with("Destroy 2 analyses? ", :add_to_history => false)
          options = {analyzer_id: analyzer_id, query: {"analyzer_version" => "v0.1.0"}, yes: true}
          expect {
            OacisCli.new.invoke(:destroy_analyses, [], options)
          }.to change { Analysis.where(analyzer_version: "v0.1.0").count }.by(-2)
        }
      end
    end
  end

  describe "#replace_analyses" do

    it "newly create analyses have the same attribute as old ones" do
      analyzer_id = @sim.analyzers.where(type: :on_run).first.id.to_s
      at_temp_dir {
        invoke_create_analyses(:on_run, {output: "analysis_ids.json", input: "azr_parameters.json"})
        Analysis.limit(2).each do |anl|
          anl.status = :failed
          anl.save
        end
        h = Analysis.first.parameters
        options = {analyzer_id: analyzer_id, query: {"status" => "failed"}, input: "azr_parameters.json", yes: true}
        expect {
          OacisCli.new.invoke(:replace_analyses, [], options)
        }.to change { Analysis.where(status: :created).count }.by(2)
        expect(Analysis.where(status: :created).first.parameters).to eq h
      }
    end

    it "destroys old analysis" do
      analyzer_id = @sim.analyzers.where(type: :on_run).first.id.to_s
      at_temp_dir {
        invoke_create_analyses(:on_run, {output: "analysis_ids.json", input: "azr_parameters.json", yes: true})
        Analysis.limit(2).each do |anl|
          anl.status = :failed
          anl.save
        end
        options = {analyzer_id: analyzer_id, query: {"status" => "failed"}, input: "azr_parameters.json", yes: true}
        expect {
          OacisCli.new.invoke(:replace_analyses, [], options)
        }.to change { Analysis.where(status: :failed).count  }.from(2).to(0)
      }
    end

    context "if user say \"no\" not to replace analyses" do

      it "replaces nothing" do
        analyzer_id = @sim.analyzers.where(type: :on_run).first.id.to_s
        at_temp_dir {
          invoke_create_analyses(:on_run, {output: "analysis_ids.json", input: "azr_parameters.json"})
          Analysis.limit(2).each do |anl|
            anl.status = :failed
            anl.save
          end
          expect(Thor::LineEditor).to receive(:readline).with("Replace 2 analyses with new ones? ", :add_to_history => false).and_return("n")
          options = {analyzer_id: analyzer_id, query: {"status" => "failed"}, input: "azr_parameters.json"}
          expect {
            OacisCli.new.invoke(:replace_analyses, [], options)
          }.not_to change { Analysis.where(status: :created).count }
        }
      end
    end
  end

  context "with yes option" do

    it "replaces analyses with out confirmation" do
      analyzer_id = @sim.analyzers.where(type: :on_run).first.id.to_s
      at_temp_dir {
        invoke_create_analyses(:on_run, {output: "analysis_ids.json", input: "azr_parameters.json"})
        Analysis.limit(2).each do |anl|
          anl.status = :failed
          anl.save
        end
        expect(Thor::LineEditor).not_to receive(:readline).with("Replace 2 analyses with new ones? ", :add_to_history => false)
        options = {analyzer_id: analyzer_id, query: {"status" => "failed"}, input: "azr_parameters.json", yes: true}
        expect {
          OacisCli.new.invoke(:replace_analyses, [], options)
        }.to change { Analysis.where(status: :created).count }.by(2)
      }
    end
  end
end

