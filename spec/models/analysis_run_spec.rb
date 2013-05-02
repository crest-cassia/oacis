require 'spec_helper'

describe AnalysisRun do

  before(:each) do
    @sim = FactoryGirl.create(:simulator, 
                              parameter_sets_count:1, runs_count:1,
                              analyzers_count: 1, run_analysis: true)
    @run = @sim.parameter_sets.first.runs.first
    @azr = @sim.analyzers.first
    @valid_attr = {
        parameters: {"param1" => 1, "param2" => 2.0},
        analyzer: @azr
    }
  end

  describe "validation" do

    it "is valid with proper attributes" do
      arn = @run.analysis_runs.build(@valid_attr)
      arn.should be_valid
    end

    it "is invalid when 'parameters' field is not given" do
      invalid_attr = @valid_attr
      invalid_attr.delete(:parameters)
      arn = @run.analysis_runs.build(invalid_attr)
      arn.should_not be_valid
    end

    it "assigns 'created' stauts by default" do
      arn = @run.analysis_runs.create!(@valid_attr)
      arn.status.should == :created
    end

    it "is invalid if Analyzer is not related" do
      invalid_attr = @valid_attr
      invalid_attr.delete(:analyzer)
      arn = @run.analysis_runs.build(invalid_attr)
      arn.should_not be_valid
    end

    it "is invalid if there is no parent document" do
      arn = AnalysisRun.new(@valid_attr)
      lambda {
        arn.save!
      }.should raise_error
    end

    it "is invalid when status is not an allowed value" do
      arn = @run.analysis_runs.create!(@valid_attr)

      arn.status = :status_XXX
      arn.should_not be_valid
    end

    it "casts the parameter values according to the definition" do
      updated_attr = @valid_attr.update(parameters: {"param1"=>"32","param2"=>"2.0"})
      arn = @run.analysis_runs.create!(updated_attr)
      arn.parameters["param1"].should be_a(Integer)
      arn.parameters["param2"].should be_a(Float)
    end

    it "adopts default values if the parameter is not explicitly specified" do
      updated_attr = @valid_attr.update(parameters: {"param1"=>"32"})
      arn = @run.analysis_runs.create!(updated_attr)
      default_val = arn.analyzer.parameter_definitions["param2"]["default"]
      arn.parameters["param2"].should eq(default_val)
    end
  end

  describe "accessibility" do

    it "result is not an accessible field" do
      arn = @run.analysis_runs.build(@valid_attr.update(result: "abc"))
      arn.result.should be_nil
    end

    it "status is not an accessible field" do
      arn = @run.analysis_runs.build(@valid_attr.update(status: :running))
      arn.status.should_not == :running
    end
  end

  describe "relation" do

    it "can be embedded in a run" do
      @arn = @run.analysis_runs.build(@valid_attr)
      @run.analysis_runs.last.should be_a(AnalysisRun)
      @arn.analyzable.should be_a(Run)
    end

    it "can be embedded in a parameter_set" do
      ps = @sim.parameter_sets.first
      @arn = ps.analysis_runs.build(@valid_attr)
      ps.analysis_runs.last.should be_a(AnalysisRun)
      @arn.analyzable.should be_a(ParameterSet)
    end

    it "refers to analyzer" do
      @arn = @run.analysis_runs.create!(@valid_attr)
      @arn.reload
      @arn.analyzer.should be_a(Analyzer)
    end
  end

  describe "#update_status_running" do

    before(:each) do
      @arn = @run.analysis_runs.first
    end

    it "updates status to 'running' and sets hostname" do
      ret = @arn.update_status_running(hostname: 'host_ABC')
      ret.should be_true

      @arn.reload
      @arn.status.should == :running
      @arn.hostname.should == 'host_ABC'
    end
  end

  describe "#update_status_including" do

    before(:each) do
      @arn = @run.analysis_runs.first
      @arn.update_status_running(:hostname => 'host_ABC')
    end

    it "updates status to 'including' and 'finished_at'" do
      ret = @arn.update_status_including
      ret.should be_true

      @arn.reload
      @arn.status.should == :including
      @arn.result.should be_nil
      @arn.finished_at.should_not be_nil
      @arn.included_at.should be_nil
    end

    it "also updates cpu- and real-times" do
      ret = @arn.update_status_including(cpu_time: 1.5, real_time: 2.0)
      @arn.reload
      @arn.cpu_time.should == 1.5
      @arn.real_time.should == 2.0
    end

    it "also updates 'result'" do
      result = {xxx: "abc", yyy: 12345}
      ret = @arn.update_status_including(result: result, cpu_time: 1.5, real_time: 2.0)
      @arn.reload
      @arn.result["xxx"].should eq("abc")
      @arn.result["yyy"].should eq(12345)
    end
  end

  describe "#update_status_finished" do

    before(:each) do
      @arn = @run.analysis_runs.first
      @arn.update_status_running(:hostname => 'host_ABC')
      @arn.update_status_including(result: {x:1.0}, cpu_time: 1.5, real_time: 2.0)
    end

    it "updates status to 'finished'" do
      ret = @arn.update_status_finished
      ret.should be_true
      @arn.reload
      @arn.status.should eq(:finished)
      @arn.included_at.should_not be_nil
    end
  end

  describe "#input" do

    describe "for :on_run type" do

      before(:each) do
        @arn = @run.analysis_runs.first
      end

      it "returns a Hash having 'simulation_parameters'" do
        @arn.input[:simulation_parameters].should eq(@run.parameter_set.v)
      end

      it "returns a Hash having 'analysis_parameters'" do
        @arn.input[:analysis_parameters].should eq(@arn.parameters)
      end

      it "returns a Hash having result of Run" do
        @run.result = {"xxx" => 1234, "yyy" => 0.5}
        @run.save!
        @arn.input[:result].should eq(@run.result)
      end
    end

    describe "for :on_parameter_set type" do

      it "returns an appropriate hash" do
        pending "not yet implemented"
      end
    end

    describe "for :on_parameter_sets_group type" do

      it "returns an appropriate hash" do
        pending "not yet implemented"
      end
    end
  end
end
