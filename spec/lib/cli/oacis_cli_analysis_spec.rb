require 'spec_helper'
require File.join(Rails.root, 'lib/cli/oacis_cli')

describe OacisCli do

  before(:each) do
    @sim = FactoryGirl.create(:simulator, parameter_sets_count: 2, runs_count: 0, finished_runs_count: 2, analyzers_count: 1, run_analysis: false, analyzers_on_parameter_set_count: 1, run_analysis_on_parameter_set: false)
    @sim.save!
  end

  def create_options(option={})
    options = { analyzers: 'analyzers.json', number_of_analyses: 1, output: 'analysis_ids.json' }
    options.merge!(option)
    options
  end

  def invoke_create_analyses(type, option={})
    io = File.open('analyzers.json','w')
    case type
    when :on_run
      io.puts @sim.analyzers.where(type: :on_run).map {|anz| {"analyzer_id"=>anz.id.to_s}}.to_json
    when :on_parameter_set
      io.puts @sim.analyzers.where(type: :on_parameter_set).map {|anz| {"analyzer_id"=>anz.id.to_s}}.to_json
    when :each
      io.puts @sim.analyzers.map {|anz| {"analyzer_id"=>anz.id.to_s}}.to_json
    end
    io.close
    options = create_options(option)
    OacisCli.new.invoke(:create_analyses, [], options)
  end


  describe "#analyses_template" do

    it "outputs a template of analyses" do
      at_temp_dir {
        options = { simulator: @sim.id.to_s, output: 'analyzers.json' }
        OacisCli.new.invoke(:analyses_template, [], options)
        File.exist?('analyzers.json').should be_true
        expect {
          JSON.load(File.read('analyzers.json'))
        }.not_to raise_error
      }
    end

    it "outputs a template having default analysis parameters" do
      at_temp_dir {
        options = { simulator: @sim.id.to_s, output: 'analyzers.json' }
        OacisCli.new.invoke(:analyses_template, [], options)
        expected = @sim.analyzers.map {|anz| {"analyzer_id"=>anz.id.to_s}}
        JSON.load(File.read('analyzers.json')).should eq expected
      }
    end

    it "when simulator id is invalid" do
      at_temp_dir {
        options = { simulator: "DO_NOT_EXIST", output: 'analyzers.json' }
        expect {
          OacisCli.new.invoke(:analyses_template, [], options)
        }.to raise_error
      }
    end

    context "when dry_run option is specified" do

      it "does not create output file" do
        at_temp_dir {
          options = { simulator: @sim.id.to_s, output: 'analyzres.json', dry_run: true }
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

    it "creates analyses on runs and parameter_sets" do
      at_temp_dir {
        expect {
          invoke_create_analyses(:each)
        }.to change { Analysis.count }.by(6)
      }
    end

    it "outputs ids of created analyses in json" do
      at_temp_dir {
        invoke_create_analyses(:each, {output: 'analysis_ids_tmp.json'})

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
            invoke_create_analyses(:on_run, {runs: "runs.json"})
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
            invoke_create_analyses(:on_parameter_set, {parameter_sets: "parameter_sets.json"})
          }.to change { Analysis.where(analyzable_type: "ParameterSet").count }.by(1)
        }
      end
    end

    context "when analyses exists" do

      before(:each) do
        invoke_create_analyses(:each, {number_of_analyses: 1})
      end

      it "iterates creation of analyses up to the specified number" do
        at_temp_dir {
          expect {
            invoke_create_analyses(:each, {number_of_analyses: 2})
          }.to change { Analysis.count }.by(6)
        }
      end

      it "outputs ids of created and existing runs up to the specified number" do
        at_temp_dir {
          invoke_create_analyses(:each, {number_of_analyses: 2, output: "analysis_ids_tmp.json"})

          File.exist?('analysis_ids_tmp.json').should be_true
          expected = Analysis.all.map {|anl| {"analysis_id" => anl.id.to_s} }.sort_by {|h| h["analysis_id"]}
          JSON.load(File.read('analysis_ids_tmp.json')).should =~ expected
        }
      end
    end

    context "when number_of_analyses are invalid" do

      it "raises an exception" do
        at_temp_dir {
          expect {
            invoke_create_analyses(:each, {number_of_analyses: 0})
          }.to raise_error
        }
        at_temp_dir {
          expect {
            invoke_create_analyses(:each, {number_of_analyses: -1})
          }.to raise_error
        }
      end
    end

    context "when dry_run option is given" do

      it "does not save Anasyses" do
        at_temp_dir {
          expect {
            invoke_create_analyses(:each, {number_of_analyses: 1, dry_run: true})
          }.to_not change { Analysis.count }
        }
      end

      it "does not create output file" do
        at_temp_dir {
          invoke_create_analyses(:each, {number_of_analyses: 1, output: "analysis_ids_dry_run.json", dry_run: true})
          File.exist?('analysis_ids_dry_run.json').should be_false
        }
      end
    end
  end


  describe "#analysis_status" do

    it "shows number of analysis for each status in json" do
      at_temp_dir {
        invoke_create_analyses(:each, output: "analysis_ids.json")
        options = {analysis_ids: 'analysis_ids.json'}
        captured = capture(:stdout) {
          OacisCli.new.invoke(:analysis_status, [], options)
        }
        loaded = JSON.load(captured)
        loaded["total"].should eq 6
        loaded["created"].should eq 6
        loaded["finished"].should eq 0
      }
    end
  end

  describe "#destroy_analyses" do

    it "destroys analyses specified by 'status'" do
      $stdin.should_receive(:gets).and_return("y")
      at_temp_dir {
        invoke_create_analyses(:each, output: "analysis_ids.json")
        Analysis.limit(5).each do |anl|
          anl.status = :failed
          anl.save
        end
        options = {analyzers: 'analyzers.json', query: {"status" => "failed"} }
        expect {
          OacisCli.new.invoke(:destroy_analyses, [], options)
        }.to change { Analysis.where(status: :failed).count }.by(-5)
      }
    end

    context "when query option is invalid" do
      it "raises an exception" do
        at_temp_dir {
          invoke_create_analyses(:each, output: "analysis_ids.json")
          options = {analyzers: 'analyzers.json', query: "DO_NOT_EXIST" }
          expect {
            OacisCli.new.invoke(:destroy_analyses, [], options)
          }.to raise_error
          options = {analyzers: 'analyzers.json', query: { "status" => "DO_NOT_EXIST" } }
          expect {
            OacisCli.new.invoke(:destroy_analyses, [], options)
          }.to raise_error
        }
      end
    end
  end

  describe "#replace_analyses" do

    it "newly create analyses have the same attribute as old ones" do
      $stdin.should_receive(:gets).and_return("y")
      at_temp_dir {
        invoke_create_analyses(:each, output: "analysis_ids.json")
        Analysis.limit(5).each do |anl|
          anl.status = :failed
          anl.save
        end
        h = Analysis.first.parameters
        options = {analyzers: 'analyzers.json', query: {"status" => "failed"} }
        expect {
          OacisCli.new.invoke(:replace_analyses, [], options)
        }.to change { Analysis.where(status: :created).count }.by(5)
        Analysis.where(status: :created).first.parameters.should eq h
      }
    end

    it "destroys old analysis" do
      $stdin.should_receive(:gets).and_return("y")
      at_temp_dir {
        invoke_create_analyses(:each, output: "analysis_ids.json")
        Analysis.limit(5).each do |anl|
          anl.status = :failed
          anl.save
        end
        options = {analyzers: 'analyzers.json', query: {"status" => "failed"} }
        expect {
          OacisCli.new.invoke(:replace_analyses, [], options)
        }.to change { Analysis.where(status: :failed).count  }.from(5).to(0)
      }
    end
  end
end
