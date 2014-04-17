require 'spec_helper'
require File.join(Rails.root, 'lib/cli/oacis_cli')

describe OacisCli do

  before(:each) do
    @sim = FactoryGirl.create(:simulator, parameter_sets_count: 2, runs_count: 0, finished_runs_count: 2, analyzers_count: 1, run_analysis: false, analyzers_on_parameter_set_count: 1, run_analysis_on_parameter_set: false)
    @sim.save!

    class OacisCli
      private
      def yes?(str) # define as a private method otherwise mock will define the method as public
        true
      end
    end
  end

  def create_options(option={})
    options = { output: 'analysis_ids.json' }
    options.merge!(option)
    options
  end

  def invoke_create_analyses(type, option={})
    analyzer_id = nil
    case type
    when :on_run
      analyzer_id = @sim.analyzers.where(type: :on_run).first.id
    when :on_parameter_set
      analyzer_id = @sim.analyzers.where(type: :on_parameter_set).first.id
    end
    option.merge!({analyzer_id: analyzer_id})
    options = create_options(option)
    OacisCli.new.invoke(:analyses_template, [], {analyzer_id: analyzer_id, output: "anz_parameters.json"})
    OacisCli.new.invoke(:create_analyses, [], options)
  end


  describe "#analyses_template" do

    it "outputs a template of analyses" do
      at_temp_dir {
        options = { analyzer_id: @sim.analyzers.first.id.to_s, output: 'anz_parameters.json' }
        OacisCli.new.invoke(:analyses_template, [], options)
        File.exist?('anz_parameters.json').should be_true
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
        JSON.load(File.read('anz_parameters.json')).should eq [Hash[expected]]
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
          File.exist?('analyzers.json').should be_false
        }
      end
    end
  end

  describe "#create_analyses" do

    it "creates analyses on finished runs" do
      at_temp_dir {
        expect {
          invoke_create_analyses(:on_run, {input: "anz_parameters.json"})
        }.to change { Analysis.where(analyzable_type: "Run").count }.by(4)
      }
    end

    it "creates analyses on parameter_sets" do
      at_temp_dir {
        expect {
          invoke_create_analyses(:on_parameter_set, {input: "anz_parameters.json"})
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
          invoke_create_analyses(:on_parameter_set, {input: "anz_parameters.json"})
        }.to change { Analysis.where(analyzable_type: "ParameterSet").count }.by(1)

      }
    end

    it "outputs ids of created analyses in json" do
      at_temp_dir {
        invoke_create_analyses(:on_run, {output: 'analysis_ids_tmp.json', input: "anz_parameters.json"})

        File.exist?('analysis_ids_tmp.json').should be_true
        expected = Analysis.all.map {|anl| {"analysis_id" => anl.id.to_s} }.sort_by {|h| h["analysis_id"]}
        JSON.load(File.read('analysis_ids_tmp.json')).should =~ expected
      }
    end

    context "when :runs argument exists" do

      it "creates analyses on :runs" do
        at_temp_dir {
          expect {
            io = File.open('runs.json','w')
            a = []
            @sim.parameter_sets.each do |ps|
              h = {"run_id" => ps.runs.first.id }
              a << h
            end
            io.puts a.to_json
            io.close
            invoke_create_analyses(:on_run, {target: "runs.json", input: "anz_parameters.json"})
          }.to change { Analysis.where(analyzable_type: "Run").count }.by(2)
        }
      end
    end

    context "when :parameter_sets argument exists" do

      it "creates analyses on :parameter_sets" do
        at_temp_dir {
          expect {
            io = File.open('parameter_sets.json','w')
            a = [{"parameter_set_id" => @sim.parameter_sets.first.id }]
            io.puts a.to_json
            io.close
            invoke_create_analyses(:on_parameter_set, {target: "parameter_sets.json", input: "anz_parameters.json"})
          }.to change { Analysis.where(analyzable_type: "ParameterSet").count }.by(1)
        }
      end
    end

    context "when :first_run_only argument exists" do

      describe "creates analyses only on the first_run of each parameter_sets" do
        subject { -> {
                       at_temp_dir {
                         invoke_create_analyses(:on_run, {first_run_only: "first_run_only", input: "anz_parameters.json"})
                       }
                     }
        }
        it { should change { Analysis.count }.by(2) }
        it { should change { Analysis.where(parameter_set_id: @sim.parameter_sets.first.id).count }.by(1) }
      end
    end

    context "when analyses exists" do

      before(:each) do
        at_temp_dir {
          invoke_create_analyses(:on_run, {first_run_only: "first_run_only", input: "anz_parameters.json"})
        }
      end

      it "iterates creation of analyses on runs without same analyzer and analyzers parameter" do
        at_temp_dir {
          expect {
            invoke_create_analyses(:on_run, {input: "anz_parameters.json"})
          }.to change { Analysis.count }.by(2)
        }
      end

      it "outputs ids of created and existing analyses" do
        at_temp_dir {
          invoke_create_analyses(:on_run, {output: "analysis_ids_tmp.json", input: "anz_parameters.json"})

          File.exist?('analysis_ids_tmp.json').should be_true
          expected = Analysis.all.map {|anl| {"analysis_id" => anl.id.to_s} }.sort_by {|h| h["analysis_id"]}
          JSON.load(File.read('analysis_ids_tmp.json')).should =~ expected
        }
      end
    end

    context "when dry_run option is given" do

      it "does not save Anasyses" do
        at_temp_dir {
          expect {
            invoke_create_analyses(:on_run, {dry_run: true, input: "anz_parameters.json"})
          }.to_not change { Analysis.count }
        }
      end

      it "does not create output file" do
        at_temp_dir {
          invoke_create_analyses(:on_run, {output: "analysis_ids_dry_run.json", dry_run: true, input: "anz_parameters.json"})
          File.exist?('analysis_ids_dry_run.json').should be_false
        }
      end
    end

    context "when both target option and first_run_only option are given" do

      it "raise an error" do
        at_temp_dir {
          options = { target: "some thing", first_run_only: "first_run_only", input: "anz_parameters.json"}
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
        Analysis.first.parameters.should eq Hash[expected]
      end
    end
  end

  describe "#analysis_status" do

    it "shows number of analysis for each status in json" do
      at_temp_dir {
        invoke_create_analyses(:on_run, {output: "analysis_ids.json", input: "anz_parameters.json"})
        options = {analysis_ids: 'analysis_ids.json'}
        captured = capture(:stdout) {
          OacisCli.new.invoke(:analysis_status, [], options)
        }
        loaded = JSON.load(captured)
        loaded["total"].should eq 4
        loaded["created"].should eq 4
        loaded["finished"].should eq 0
      }
    end
  end

  describe "#destroy_analyses" do

    it "destroys analyses specified by 'status'" do
      analyzer_id = @sim.analyzers.where(type: :on_run).first.id
      at_temp_dir {
        invoke_create_analyses(:on_run, {output: "analysis_ids.json", input: "anz_parameters.json"})
        Analysis.limit(3).each do |anl|
          anl.status = :failed
          anl.save
        end
        options = {analyzer_id: analyzer_id, query: {"status" => "failed"} }
        expect {
          OacisCli.new.invoke(:destroy_analyses, [], options)
        }.to change { Analysis.where(status: :failed).count }.by(-3)
      }
    end

    context "when query option is invalid" do
      it "raises an exception" do
        analyzer_id = @sim.analyzers.where(type: :on_run).first.id
        at_temp_dir {
          invoke_create_analyses(:on_run, {output: "analysis_ids.json", input: "anz_parameters.json"})
          options = {analyzer_id: analyzer_id, query: "DO_NOT_EXIST" }
          expect {
            OacisCli.new.invoke(:destroy_analyses, [], options)
          }.to raise_error
          options = {analyzer_id: analyzer_id, query: { "status" => "DO_NOT_EXIST" } }
          expect {
            OacisCli.new.invoke(:destroy_analyses, [], options)
          }.to raise_error
        }
      end
    end
  end

  describe "#replace_analyses" do

    it "newly create analyses have the same attribute as old ones" do
      analyzer_id = @sim.analyzers.where(type: :on_run).first.id
      at_temp_dir {
        invoke_create_analyses(:on_run, {output: "analysis_ids.json", input: "anz_parameters.json"})
        Analysis.limit(2).each do |anl|
          anl.status = :failed
          anl.save
        end
        h = Analysis.first.parameters
        options = {analyzer_id: analyzer_id, query: {"status" => "failed"}, input: "anz_parameters.json"}
        expect {
          OacisCli.new.invoke(:replace_analyses, [], options)
        }.to change { Analysis.where(status: :created).count }.by(2)
        Analysis.where(status: :created).first.parameters.should eq h
      }
    end

    it "destroys old analysis" do
      analyzer_id = @sim.analyzers.where(type: :on_run).first.id
      at_temp_dir {
        invoke_create_analyses(:on_run, {output: "analysis_ids.json", input: "anz_parameters.json"})
        Analysis.limit(2).each do |anl|
          anl.status = :failed
          anl.save
        end
        options = {analyzer_id: analyzer_id, query: {"status" => "failed"}, input: "anz_parameters.json"}
        expect {
          OacisCli.new.invoke(:replace_analyses, [], options)
        }.to change { Analysis.where(status: :failed).count  }.from(2).to(0)
      }
    end
  end
end
