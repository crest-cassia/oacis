require 'spec_helper'

describe RunsController do

  # This should return the minimal set of values that should be in the session
  # in order to pass any filters (e.g. authentication) defined in
  # RunsController. Be sure to keep this updated too.
  def valid_session
    {}
  end

  before(:each) do
    @sim = FactoryGirl.create(:simulator,
      parameter_sets_count: 1,
      runs_count: 1,
      analyzers_count: 1,
      run_analysis: true,
      parameter_set_queries_count:1
      )
    @par = @sim.parameter_sets.first
    @run = @par.runs.first
    @arn = @run.analysis_runs
  end

  describe "GET 'show'" do

    it "returns http success" do
      get 'show', {id: @run}, valid_session
      response.should be_success
    end

    it "assigns instance variables" do
      get 'show', {id: @run}, valid_session
      assigns(:run).should eq(@run)
      assigns(:param_set).should eq(@par)
    end

    it "assigns 'analysis_runs' variable" do
      get 'show', {id: @run}, valid_session
      assigns(:analysis_runs).should eq(@run.analysis_runs)
    end
  end

  describe "POST 'create'" do

    before(:each) do
      @req_param = {parameter_set_id: @par}
    end

    describe "with valid parameters" do

      it "creates a new run" do
        expect {
          post 'create', @req_param, valid_session
        }.to change(Run.where(parameter_set_id: @par), :count).by(1)
      end

      it "redirects to show page" do
        post 'create', @req_param, valid_session
        run = Run.last
        # parameter = run.parameter_set
        response.should redirect_to(run)
      end

      it "assigns seed specified by request parameter" do
        seed_val = 12345
        @req_param.update(run: {seed: seed_val})
        post 'create', @req_param, valid_session
        Run.where(parameter_set_id: @par).last.seed.should == seed_val
      end
    end

    describe "with invalid parameters" do

      it "raises an error when the ParameterSet is not found" do
        @req_param.update(parameter_set_id: 1234)
        lambda {
          post 'create', @req_param, valid_session
        }.should raise_error
      end

      it "fails with a duplicated seed" do
        seed_val = @par.runs.first.seed
        @req_param.update(run: {seed: seed_val})
        expect {
          post 'create', @req_param, valid_session
        }.to change(Run, :count).by(0)
      end

      it "redirects to parameter_sets#show path" do
        seed_val = @par.runs.first.seed
        @req_param.update(run: {seed: seed_val})
        post 'create', @req_param, valid_session
        response.should redirect_to(@par)
      end
    end
  end
end
