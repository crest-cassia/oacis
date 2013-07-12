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
      run_analysis: true
      )
    @par = @sim.parameter_sets.first
    @run = @par.runs.first
    @arn = @run.analyses
  end

  describe "GET 'index'" do

    it "returns http success" do
      get 'index', {}, valid_session
      response.should be_success
    end
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

    it "assigns 'analyses' variable" do
      get 'show', {id: @run}, valid_session
      assigns(:analyses).should eq(@run.analyses)
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

      it "redirects to ParameterSetController#show page" do
        post 'create', @req_param, valid_session
        response.should redirect_to(@par)
      end

      it "assigns seed specified by request parameter" do
        seed_val = 12345
        @req_param.update(run: {seed: seed_val})
        post 'create', @req_param, valid_session
        Run.where(parameter_set_id: @par).last.seed.should == seed_val
      end

      it "create multiple items when params[num_runs] is given" do
        num_runs = 3
        expect {
          post 'create', @req_param.update(num_runs: num_runs), valid_session
        }.to change(Run.where(parameter_set_id: @par), :count).by(num_runs)
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

  describe "DELETE destroy" do

    it "destroys the requested run" do
      expect {
        delete :destroy, {id: @run.to_param}, valid_session
      }.to change(Run, :count).by(-1)
    end

    it "redirects to the hosts list" do
      delete :destroy, {id: @run.to_param}, valid_session
      response.should redirect_to(runs_url)
    end
  end
end
