require 'spec_helper'
require File.join(Rails.root, 'lib/cli/oacis_cli')

describe OacisCli do

  before(:each) do
    @sim = FactoryGirl.create(:simulator, parameter_sets_count: 2, runs_count: 0, finished_runs_count: 2, analyzers_count: 1, run_analysis: false, analyzers_on_parameter_set_count: 1, run_analysis_on_parameter_set: false)
    @sim.save!
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
    option.merge!({analyzer_id: analyzer_id, input: "anz_parameters.json"})
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

    it "do not create analyses on parameter_sets having :created runs" do
      at_temp_dir {
        expect {
          new_run = @sim.parameter_sets.first.runs.build
          new_run.save!
          invoke_create_analyses(:on_parameter_set)
        }.to change { Analysis.where(analyzable_type: "ParameterSet").count }.by(1)
      }
    end

    it "outputs ids of created analyses in json" do
      at_temp_dir {
        invoke_create_analyses(:on_run, {output: 'analysis_ids_tmp.json'})

        File.exist?('analysis_ids_tmp.json').should be_true
        expected = Analysis.all.map {|anl| {"analysis_id" => anl.id.to_s} }.sort_by {|h| h["analysis_id"]}
        JSON.load(File.read('analysis_ids_tmp.json')).should =~ expected
      }
    end

    context "when :runs argument exits" do

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
            invoke_create_analyses(:on_run, {target: "runs.json"})
          }.to change { Analysis.where(analyzable_type: "Run").count }.by(2)
        }
      end
    end

    context "when :parameter_sets argument exits" do

      it "creates analyses on :parameter_sets" do
        at_temp_dir {
          expect {
            io = File.open('parameter_sets.json','w')
            a = [{"parameter_set_id" => @sim.parameter_sets.first.id }]
            io.puts a.to_json
            io.close
            invoke_create_analyses(:on_parameter_set, {target: "parameter_sets.json"})
          }.to change { Analysis.where(analyzable_type: "ParameterSet").count }.by(1)
        }
      end
    end

    context "when analyses exists" do

      before(:each) do
        invoke_create_analyses(:on_run, {first_run_only: "first_run_onlyi"})
      end

      it "iterates creation of analyses on runs without same analyzer and analyzers parameter" do
        at_temp_dir {
          expect {
            invoke_create_analyses(:on_run)
          }.to change { Analysis.count }.by(3)
        }
      end

      it "outputs ids of created and existing analyses" do
        at_temp_dir {
          invoke_create_analyses(:on_run, {output: "analysis_ids_tmp.json"})

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
            invoke_create_analyses(:on_run, {number_of_analyses: 1, dry_run: true})
          }.to_not change { Analysis.count }
        }
      end

      it "does not create output file" do
        at_temp_dir {
          invoke_create_analyses(:on_run, {number_of_analyses: 1, output: "analysis_ids_dry_run.json", dry_run: true})
          File.exist?('analysis_ids_dry_run.json').should be_false
        }
      end
    end

    context "when both target option and first_run_only option are given" do

      it "raise an error" do
        at_temp_dir {
          options = { target: "some thing", first_run_only: "first_run_only" }
          expect {
            invoke_create_analyses(:on_run, options)
          }.to raise_error
        }
      end
    end
  end


  describe "#analysis_status" do

    it "shows number of analysis for each status in json" do
      at_temp_dir {
        invoke_create_analyses(:on_run, output: "analysis_ids.json")
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
      $stdin.should_receive(:gets).and_return("y")
      at_temp_dir {
        invoke_create_analyses(:on_run, output: "analysis_ids.json")
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
          invoke_create_analyses(:on_run, output: "analysis_ids.json")
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
      $stdin.should_receive(:gets).and_return("y")
      at_temp_dir {
        invoke_create_analyses(:on_run, output: "analysis_ids.json")
        Analysis.limit(2).each do |anl|
          anl.status = :failed
          anl.save
        end
        h = Analysis.first.parameters
        options = {analyzer_id: analyzer_id, query: {"status" => "failed"} }
        expect {
          OacisCli.new.invoke(:replace_analyses, [], options)
        }.to change { Analysis.where(status: :created).count }.by(2)
        Analysis.where(status: :created).first.parameters.should eq h
      }
    end

    it "destroys old analysis" do
      analyzer_id = @sim.analyzers.where(type: :on_run).first.id
      $stdin.should_receive(:gets).and_return("y")
      at_temp_dir {
        invoke_create_analyses(:on_run, output: "analysis_ids.json")
        Analysis.limit(2).each do |anl|
          anl.status = :failed
          anl.save
        end
        options = {analyzer_id: analyzer_id, query: {"status" => "failed"} }
        expect {
          OacisCli.new.invoke(:replace_analyses, [], options)
        }.to change { Analysis.where(status: :failed).count  }.from(2).to(0)
      }
    end
  end
end
