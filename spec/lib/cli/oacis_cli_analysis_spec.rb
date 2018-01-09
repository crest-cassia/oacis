require 'spec_helper'
require File.join(Rails.root, 'lib/cli/oacis_cli')

describe OacisCli do

  before(:each) do
    @host = FactoryBot.create(:host_with_parameters)
    @sim = FactoryBot.create(:simulator, parameter_sets_count: 2, runs_count: 0,
                              finished_runs_count: 2,
                              analyzers_count: 1, run_analysis: false,
                              analyzers_on_parameter_set_count: 1,
                              run_analysis_on_parameter_set: false)
    @sim.analyzers.each do |azr|
      azr.update_attribute(:support_mpi, true)
      azr.update_attribute(:support_omp, true)
    end
  end

  def create_job_parameters_json(path)
    File.open(path, 'w') {|io|
      job_parameters = {
        "submitted_to" => @host.id.to_s,
        "host_parameters" => {"param1" => "foo", "param2" => "bar"},
        "mpi_procs" => 2,
        "omp_threads" => 8,
        "priority" => 0
      }
      io.puts job_parameters.to_json
      io.flush
    }
  end

  def invoke_create_analyses(type, option={})
    case type
    when :on_run
      analyzer_id = @sim.analyzers.where(type: :on_run).first.id.to_s
    when :on_parameter_set
      analyzer_id = @sim.analyzers.where(type: :on_parameter_set).first.id.to_s
    end
    create_job_parameters_json('job_parameters.json')
    options = { analyzer_id: analyzer_id, input: 'azr_parameters.json',
                output: 'analysis_ids.json', job_parameters: 'job_parameters.json'}
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
        }.to raise_error Mongoid::Errors::DocumentNotFound
      }
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

    it "creates analyses on finished runs with correct attributes" do
      at_temp_dir {
        expect {
          invoke_create_analyses(:on_run)
        }.to change { Analysis.where(analyzable_type: "Run").count }.by(4)
        anl = Analysis.where(analyzable_type: "Run").first
        expect(anl.submitted_to).to eq @host
        expect(anl.mpi_procs).to eq 2
        expect(anl.omp_threads).to eq 8
        expect(anl.priority).to eq 0
        expect(anl.host_parameters).to eq({"param1" => "foo", "param2" => "bar"})
      }
    end

    it "creates analyses on parameter_sets" do
      at_temp_dir {
        expect {
          invoke_create_analyses(:on_parameter_set)
        }.to change { Analysis.where(analyzable_type: "ParameterSet").count }.by(2)
        anl = Analysis.where(analyzable_type: "ParameterSet").first
        expect(anl.submitted_to).to eq @host
        expect(anl.mpi_procs).to eq 2
        expect(anl.omp_threads).to eq 8
        expect(anl.priority).to eq 0
        expect(anl.host_parameters).to eq({"param1" => "foo", "param2" => "bar"})
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

    context "when both target option and first_run_only option are given" do

      it "raise an error" do
        at_temp_dir {
          options = { target: "some thing", first_run_only: "first_run_only"}
          expect {
            invoke_create_analyses(:on_run, options)
          }.to raise_error(/can not use both first_run_only option and target option/)
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
        invoke_create_analyses(:on_run)
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
        invoke_create_analyses(:on_run)
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
        invoke_create_analyses(:on_run)
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
          invoke_create_analyses(:on_run)
          options = {analyzer_id: analyzer_id, query: "DO_NOT_EXIST", yes: true}
          expect {
            capture_stdout_stderr {
              OacisCli.new.invoke(:destroy_analyses, [], options)
            }
          }.to raise_error(/invalid query/)
          options = {analyzer_id: analyzer_id, query: { "status" => "DO_NOT_EXIST" }, yes: true}
          expect {
            OacisCli.new.invoke(:destroy_analyses, [], options)
          }.to raise_error(/No analysis is found with query/)
          options = {analyzer_id: analyzer_id, query: { "analyzer_version" => "DO_NOT_EXIST" }, yes: true}
          expect {
            OacisCli.new.invoke(:destroy_analyses, [], options)
          }.to raise_error(/No analysis is found with query/)
        }
      end
    end

    context "if user say \"no\" not to destroy analyses" do

      it "destroys nothing" do
        analyzer_id = @sim.analyzers.where(type: :on_run).first.id.to_s
        at_temp_dir {
          invoke_create_analyses(:on_run)
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
          invoke_create_analyses(:on_run)
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

  describe "#destroy_analyses_by_ids" do

    before(:each) do
      @sim = FactoryBot.create(:simulator,
                                parameter_sets_count: 1,
                                finished_runs_count: 5,
                                run_analysis: true)
    end

    it "destroys analyses specified by ids" do
      at_temp_dir {
        options = {}
        anl_ids = Analysis.all.map(&:id)[0..2].map(&:to_s)
        expect {
          OacisCli.new.invoke(:destroy_analyses_by_ids, anl_ids, options)
        }.to change { Analysis.count }.by(-3)
      }
    end

    it "ignore runs which are not found, when -y is given" do
      at_temp_dir {
        options = {yes: true}
        anl_ids = Analysis.all.map(&:id)[0..2].map(&:to_s) + ["DO_NOT_EXIST"]
        expect {
          capture_stdout_stderr {
            OacisCli.new.invoke(:destroy_analyses_by_ids, anl_ids, options)
          }
        }.to change { Analysis.count }.by(-3)
      }
    end
  end

  describe "#replace_analyses" do

    def prepare_finished_and_failed_analyses
      invoke_create_analyses(:on_run)
      Analysis.limit(2).each do |anl|
        anl.update_attribute(:status, :failed)
      end
      Analysis.where(status: :created).each do |anl|
        anl.update_attribute(:status, :finished)
      end
    end

    it "newly create analyses have the same attribute as old ones" do
      analyzer_id = @sim.analyzers.where(type: :on_run).first.id.to_s
      at_temp_dir {
        prepare_finished_and_failed_analyses

        old_anl = Analysis.where(status: :failed).first
        old_attributes = {
          parameters: old_anl.parameters,
          submitted_to: old_anl.submitted_to,
          host_parameters: old_anl.host_parameters,
          mpi_procs: old_anl.mpi_procs,
          omp_threads: old_anl.omp_threads,
          priority: old_anl.priority
        }
        options = {analyzer_id: analyzer_id, query: {"status" => "failed"}, yes: true}
        expect {
          OacisCli.new.invoke(:replace_analyses, [], options)
        }.to change { Analysis.where(status: :created).count }.by(2)
        anl = Analysis.where(status: :created).first
        expect(anl.parameters).to eq old_attributes[:parameters]
        expect(anl.submitted_to).to eq old_attributes[:submitted_to]
        expect(anl.host_parameters).to eq old_attributes[:host_parameters]
        expect(anl.mpi_procs).to eq old_attributes[:mpi_procs]
        expect(anl.omp_threads).to eq old_attributes[:omp_threads]
        expect(anl.priority).to eq old_attributes[:priority]
      }
    end

    it "destroys old analysis" do
      analyzer_id = @sim.analyzers.where(type: :on_run).first.id.to_s
      at_temp_dir {
        prepare_finished_and_failed_analyses
        options = {analyzer_id: analyzer_id, query: {"status" => "failed"}, yes: true}
        expect {
          OacisCli.new.invoke(:replace_analyses, [], options)
        }.to change { Analysis.where(status: :failed).count  }.from(2).to(0)
      }
    end

    context "if user say \"no\" not to replace analyses" do

      it "replaces nothing" do
        analyzer_id = @sim.analyzers.where(type: :on_run).first.id.to_s
        at_temp_dir {
          prepare_finished_and_failed_analyses

          expect(Thor::LineEditor).to receive(:readline).with("Replace 2 analyses with new ones? ", :add_to_history => false).and_return("n")
          options = {analyzer_id: analyzer_id, query: {"status" => "failed"} }
          expect {
            OacisCli.new.invoke(:replace_analyses, [], options)
          }.not_to change { Analysis.where(status: :created).count }
        }
      end
    end

    it "shows confirmation messages without :yes option" do
      analyzer_id = @sim.analyzers.where(type: :on_run).first.id.to_s
      at_temp_dir {
        prepare_finished_and_failed_analyses

        expect(Thor::LineEditor).to receive(:readline).with("Replace 2 analyses with new ones? ", :add_to_history => false).and_return("y")
        options = {analyzer_id: analyzer_id, query: {"status" => "failed"} }
        expect {
          OacisCli.new.invoke(:replace_analyses, [], options)
        }.to change { Analysis.where(status: :created).count }.by(2)
      }
    end
  end

  describe "#replace_analyses_by_ids" do

    before(:each) do
      FactoryBot.create(:simulator,
                               parameter_sets_count: 1,
                               finished_runs_count: 5,
                               run_analysis: true)
    end

    it "replaces analyses specified by ids" do
      at_temp_dir {
        options = {}
        anl_ids = Analysis.all.map(&:id)[0..2].map(&:to_s)
        expect {
          OacisCli.new.invoke(:replace_analyses_by_ids, anl_ids, options)
        }.to_not change { Analysis.count }

        expect( (Analysis.all.map(&:id) - anl_ids).size ).to eq Analysis.count
      }
    end

    it "ignore analyses which are not found, when -y is given" do
      at_temp_dir {
        options = {yes: true}
        anl_ids = Analysis.all.map(&:id)[0..2].map(&:to_s) + ["DO_NOT_EXIST"]
        expect {
          capture_stdout_stderr {
            OacisCli.new.invoke(:replace_analyses_by_ids, anl_ids, options)
          }
        }.to_not change { Analysis.count }

        expect( (Analysis.all.map(&:id) - anl_ids).size ).to eq Analysis.count
      }
    end
  end
end

