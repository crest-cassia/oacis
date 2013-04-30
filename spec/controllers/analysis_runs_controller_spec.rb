require 'spec_helper'

describe AnalysisRunsController do

  # This should return the minimal set of values that should be in the session
  # in order to pass any filters (e.g. authentication) defined in
  # AnalysisRunsController. Be sure to keep this updated too.
  def valid_session
    {}
  end

  before(:each) do
    @sim = FactoryGirl.create( :simulator,
      parameter_sets_count: 1,
      runs_count: 1,
      analyzers_count: 0
      )
    @par = @sim.parameter_sets.first
    @run = @par.runs.first

    FactoryGirl.create(:analyzer, 
                       simulator: @sim,
                       type: :on_run,
                       run_analysis: true
                       )
    @arn = @run.analysis_runs.first
  end

  describe "GET 'show'" do

    describe "for analysis_on_run" do

      it "returns http success" do
        get 'show', {run_id: @run, id: @arn}, valid_session
        response.should be_success
      end

      it "assigns instance variables for analysis_on_run" do
        get 'show', {run_id: @run, id: @arn}, valid_session
        assigns(:run).should eq(@run)
        assigns(:param_set).should eq(@par)
        assigns(:simulator).should eq(@sim)
        assigns(:analysis_run).should eq(@arn)
      end
    end
  end

  describe "GET 'create'" do
    it "returns http success" do
      post 'create', {run_id: @run}, valid_session
      response.should be_success
    end
  end

end
