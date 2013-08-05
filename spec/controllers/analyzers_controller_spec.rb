require 'spec_helper'

describe AnalyzersController do

  # This should return the minimal set of values that should be in the session
  # in order to pass any filters (e.g. authentication) defined in
  # AnalyzersController. Be sure to keep this updated too.
  def valid_session
    {}
  end

  describe "GET 'show'" do

    before(:each) do
      @sim = FactoryGirl.create(:simulator,
                                parameter_sets_count:0, runs_count:0, analyzers_count:2)
      @azr = @sim.analyzers.first
    end

    it "returns http success" do
      get 'show', {id: @azr.id }
      response.should be_success
    end

    it "assigns the requested analyzer to @analyzer" do
      get 'show', {id: @azr.id }
      assigns(:analyzer).should eq(@azr)
    end
  end

  describe "GET new" do

    before(:each) do
      @sim = FactoryGirl.create(:simulator,
                                parameter_sets_count: 0, runs_count: 0, analyzers_count: 0)
    end

    it "assigns a new simulator as @simulator" do
      get :new, {simulator_id: @sim.to_param}, valid_session
      assigns(:analyzer).should be_a_new(Analyzer)
    end
  end

  describe "POST create" do

    before(:each) do
      @sim = FactoryGirl.create(:simulator,
                                parameter_sets_count: 0, runs_count: 0, analyzers_count: 0)
    end

    describe "with valid params" do

      before(:each) do
        definitions = [
          {key: "param1", type: "Integer"},
          {key: "param2", type: "Float"}
        ]
        analyzer = {
          name: "analyzerA", type: "on_run", command: "echo",
          parameter_definitions_attributes: definitions,
          auto_run: "no", description: "xxx yyy"
        }
        @valid_post_parameter = {simulator_id: @sim.id, analyzer: analyzer}
      end

      it "creates a new Analyzer" do
        expect {
          post :create, @valid_post_parameter, valid_session
        }.to change(Analyzer, :count).by(1)
      end

      it "assigns attributes of newly created Analyzer" do
        post :create, @valid_post_parameter, valid_session
        azr = Analyzer.last
        azr.name.should eq "analyzerA"
        azr.type.should eq :on_run
        azr.command.should eq "echo"
        azr.auto_run.should eq :no
        azr.description.should eq "xxx yyy"
        azr.parameter_definition_for("param1").type.should eq "Integer"
        azr.parameter_definition_for("param2").type.should eq "Float"
      end

      it "assigns a newly created analyzer as @analyzer" do
        post :create, @valid_post_parameter, valid_session
        assigns(:analyzer).should be_a(Analyzer)
        assigns(:analyzer).should be_persisted
      end

      it "redirects to the created analyzer" do
        post :create, @valid_post_parameter, valid_session
        response.should redirect_to(Analyzer.last)
      end
    end

    describe "with invalid params" do

      it "assigns a newly created but unsaved simulator as @simulator" do
        expect {
          post :create, {simulator_id: @sim.id, analyzer: {}}, valid_session
          assigns(:analyzer).should be_a_new(Analyzer)
        }.to_not change(Analyzer, :count)
      end

      it "re-renders the 'new' template" do
        # Trigger the behavior that occurs when invalid params are submitted
        post :create, {simulator_id: @sim.id, analyzer: {}}, valid_session
        response.should render_template("new")
      end
    end
  end

  describe "DELETE 'destroy'" do

    before(:each) do
      @sim = FactoryGirl.create(:simulator, parameter_sets_count: 0, analyzers_count: 1)
      @azr = @sim.analyzers.first
    end

    it "destroys the requested analyzer" do
      expect {
        delete :destroy, {simulator_id: @sim.to_param, id: @azr.to_param}, valid_session
      }.to change { @sim.reload.analyzers.count }.by(-1)
    end

    it "redirects to the simulators list" do
      delete :destroy, {simulator_id: @sim.to_param, id: @azr.to_param}, valid_session
      response.should redirect_to( simulator_url(@sim, anchor: '!tab-about') )
    end
  end

  describe "GET '_parameters_form'" do

    before(:each) do
      @sim = FactoryGirl.create(:simulator,
                                parameter_sets_count:0, runs_count:0, analyzers_count:2)
      @azr = @sim.analyzers.first
    end

    it "returns http success" do
      get '_parameters_form', {id: @azr.id}
      response.should be_success
    end
  end

end
