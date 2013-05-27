require 'spec_helper'

describe ParameterSetsController do

  # This should return the minimal set of values that should be in the session
  # in order to pass any filters (e.g. authentication) defined in
  # ParameterSetsController. Be sure to keep this updated too.
  def valid_session
    {}
  end
  
  describe "GET 'show'" do

    it "returns http success" do
      sim = FactoryGirl.create(:simulator,
                               parameter_sets_count: 1,
                               runs_count: 1,
                               analyzers_count: 1,
                               run_analysis: true)
      get 'show', {id: sim.parameter_sets.first}, valid_session
      response.should be_success
    end

    it "assigns instance variables" do
      sim = FactoryGirl.create(:simulator,
                               parameter_sets_count: 1,
                               runs_count: 1,
                               analyzers_count: 1,
                               run_analysis: true)
      prm = sim.parameter_sets.first
      get 'show', {id: prm}, valid_session
      assigns(:param_set).should eq(prm)
      assigns(:simulator).should eq(sim)
      assigns(:parameter_keys).should eq(["L","T"])
      assigns(:runs).first.should be_a(Run)
    end

    it "paginates list of runs" do
      sim = FactoryGirl.create(:simulator, parameter_sets_count:1, runs_count: 26)
      prm = sim.parameter_sets.first
      get 'show', {id: prm, page: 1}, valid_session
      assigns(:runs).count.should == 26
      assigns(:runs).to_a.size.should == 25
    end
  end

  describe "GET new" do

    before(:each) do
      @sim = FactoryGirl.create(:simulator,
                                parameter_sets_count: 0)
    end

    it "assigns instance variables @simulator and @param_set" do
      get 'new', {simulator_id: @sim}, valid_session
      assigns(:param_set).should be_a_new(ParameterSet)
      assigns(:simulator).should be_a(Simulator)
      assigns(:param_set).should respond_to(:v)
    end
  end

  describe "GET duplicate" do

    before(:each) do
      @sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 0)
      @ps = @sim.parameter_sets.first
    end

    it "assigns instance variables @simulator and @param_set with duplicated parameters" do
      get 'duplicate', {id: @ps}, valid_session
      assigns(:param_set).should be_a_new(ParameterSet)
      assigns(:simulator).should be_a(Simulator)
      assigns(:param_set).should respond_to(:v)
      assigns(:param_set).v.should eq(@ps.v)
    end
  end

  describe "POST create" do

    before(:each) do
      @sim = FactoryGirl.create(:simulator,
                                parameter_sets_count: 0)
    end

    describe "with valid params" do

      before(:each) do
        parameters = {"L" => 10, "T" => 2.0}
        @valid_param = {simulator_id: @sim, parameters: parameters}
      end

      it "creates a new ParameterSet" do
        expect {
          post :create, @valid_param, valid_session
        }.to change(ParameterSet, :count).by(1)
      end

      it "redirects to the created parameter set" do
        post :create, @valid_param, valid_session
        response.should redirect_to(ParameterSet.last)
      end
    end

    describe "with invalid params" do

      before(:each) do
        parameters = {"L" => 10, "T" => "abc"}
        @invalid_param = {simulator_id: @sim, parameters: parameters}
      end

      it "assigns a new ParameterSet as @param_set" do
        expect {
          post :create, @invalid_param, valid_session
          assigns(:param_set).should be_a_new(ParameterSet)
        }.to_not change(ParameterSet, :count)
      end

      it "re-renders the 'new' template" do
        post :create, @invalid_param, valid_session
        response.should render_template("new")
      end
    end
  end

end
