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

      it "creates runs if num_runs are given" do
        expect {
          post :create, @valid_param.update(num_runs: 3), valid_session
        }.to change { Run.count }.by(3)
      end

      describe "creation of multiple parameter sets" do

        it "creates multiple parameter sets if comma-separated-values are given" do
          @valid_param.update(parameters: {"L" => "1,2,3", "T" => "1.0, 2.0, 3.0"})
          expect {
            post :create, @valid_param, valid_session
          }.to change { ParameterSet.count }.by(9)
        end

        it "redirects to simulator when multiple parameter sets were created" do
          @valid_param.update(parameters: {"L" => "1,2,3", "T" => "1.0, 2.0, 3.0"})
          post :create, @valid_param, valid_session
          response.should redirect_to(@sim)
        end

        it "non-castable elements are skipped" do
          @valid_param.update(parameters: {"L" => "1, 2", "T" => "1.0, abc"})
          expect {
            post :create, @valid_param, valid_session
          }.to change { ParameterSet.count }.by(2)
        end

        it "redirects to parameter set when single paraemter set is created" do
          @valid_param.update(parameters: {"L" => "1", "T" => "1.0, abc"})
          post :create, @valid_param, valid_session
          response.should redirect_to(ParameterSet.last)
        end

        it "does not create duplicated parameter set" do
          @valid_param.update(parameters: {"L" => "1", "T" => "1.0, 1.0"})
          expect {
            post :create, @valid_param, valid_session
          }.to change { ParameterSet.count }.by(1)
        end

        it "creates runs for each created parameter set" do
          @valid_param.update(parameters: {"L" => "1", "T" => "1.0, 2.0"}, num_runs: 3)
          expect {
            post :create, @valid_param, valid_session
          }.to change { Run.count }.by(6)
        end
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

      describe "creation of multiple parameter sets" do

        it "does not create a ParameterSet if too much parameter sets are going to be created" do
          @invalid_param.update(parameters: {"L" => "1,2,3,4,5,6,7,8,9,10,11,12",
                                             "T" => "1,2,3,4,5,6,7,8,9,10,11,12" })
          expect {
            post :create, @invalid_param, valid_session
          }.to_not change { ParameterSet.count }
        end

        it "re-renders 'new' template" do
          @invalid_param.update(parameters: {"L" => "1,2,3,4,5,6,7,8,9,10,11,12",
                                             "T" => "1,2,3,4,5,6,7,8,9,10,11,12" })
          post :create, @invalid_param, valid_session
          response.should render_template("new")
        end
      end
    end
  end

  describe "GET _runs_list" do
    before(:each) do
      @simulator = FactoryGirl.create(:simulator,
                                      parameter_sets_count: 1, runs_count: 30,
                                      analyzers_count: 0, run_analysis: false,
                                      parameter_set_queries_count: 0
                                      )
      @param_set = @simulator.parameter_sets.first
      get :_runs_list, {id: @param_set.to_param, sEcho: 1, iDisplayStart: 0, iDisplayLength:25 , iSortCol_0: 0, sSortDir_0: "asc"}, :format => :json
      @parsed_body = JSON.parse(response.body)
    end

    it "return json format" do
      response.header['Content-Type'].should include 'application/json'
      @parsed_body["iTotalRecords"].should == 30
      @parsed_body["iTotalDisplayRecords"].should == 30
    end

    it "paginates the list of parameters" do
      @parsed_body["aaData"].size.should == 25
    end
  end

  describe "GET _runs_status_count" do
  end

  describe "GET _runs_table" do
  end
end
