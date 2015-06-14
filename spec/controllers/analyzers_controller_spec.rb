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

  describe "GET edit" do

    before(:each) do
      @sim = FactoryGirl.create(:simulator,
                                parameter_sets_count: 0, runs_count: 0, analyzers_count: 1)
      @azr = @sim.analyzers.first
    end

    it "assigns the requested simulator as @simulator" do
      get :edit, {:id => @azr.to_param}, valid_session
      assigns(:analyzer).should eq(@azr)
    end
  end


  describe "POST create" do

    before(:each) do
      @sim = FactoryGirl.create(:simulator,
                                parameter_sets_count: 0, runs_count: 0, analyzers_count: 0)
    end

    describe "with valid params" do

      before(:each) do
        definitions = {
          "0" => {key: "param1", type: "Integer"},
          "1" => {key: "param2", type: "Float"}
        }
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

      it "assigns a newly created but unsaved analyzer as @analyzer" do
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

    describe "with no permitted params" do

      before(:each) do
        definitions = {
          "0" => {key: "param1", type: "Integer"},
          "1" => {key: "param2", type: "Float", invalid: 1},
          invalid: 1
        }
        analyzer = {
          name: "analyzerA", type: "on_run", command: "echo",
          parameter_definitions_attributes: definitions,
          auto_run: "no", description: "xxx yyy",
          invalid: 1
        }
        @valid_post_parameter = {simulator_id: @sim.id, analyzer: analyzer}
      end

      it "create a new analyzer but no permitted params are not saved" do
        invalid_analyzer_params = @valid_post_parameter[:analyzer].update(admin_flg: 1)
        invalid_params = @valid_post_parameter
        invalid_params[:analyzer] = invalid_analyzer_params
        expect {
          post :create, invalid_params, valid_session
        }.to change {Analyzer.count}.by(1)
        anz = assigns(:analyzer)
        expect(anz.try(:admin_flg)).not_to eq 1
      end
    end
  end

  describe "PUT update" do

    before(:each) do
      @sim = FactoryGirl.create(:simulator,
                                parameter_sets_count: 0, runs_count: 0, analyzers_count: 1)
      @azr = @sim.analyzers.first
    end

    describe "with valid params" do

      before(:each) do
        definitions = {
          "0" => {key: "param1", type: "Integer"},
          "1" => {key: "param2", type: "Float"}
        }
        analyzer = {
          name: "analyzerA", type: "on_run", command: "echo",
          parameter_definitions_attributes: definitions,
          auto_run: "no", description: "xxx yyy"
        }
        @valid_post_parameter = {analyzer: analyzer}
      end

      it "updates the requested analyzer" do
        put :update, {:id => @azr.to_param, :analyzer => {'description' => 'yyy zzz'}}, valid_session
        anz = assigns(:analyzer)
        expect(anz.description).to eq 'yyy zzz'
      end

      it "assigns the requested analyzer as @analyzer" do
        put :update, {:id => @azr.to_param, :analyzer => @valid_post_parameter}, valid_session
        assigns(:analyzer).should eq(@azr)
      end

      it "redirects to the analyzer" do
        put :update, {:id => @azr.to_param, :analyzer => @valid_post_parameter}, valid_session
        response.should redirect_to(@azr)
      end
    end

    describe "with invalid params" do

      it "assigns the simulator as @simulator" do
        Analyzer.any_instance.stub(:update_attributes).and_return(false)
        put :update, {:id => @azr.to_param, :analyzer => {}}, valid_session
        assigns(:analyzer).should eq(@azr)
      end

      it "re-renders the 'edit' template" do
        Analyzer.any_instance.stub(:update_attributes).and_return(false)
        put :update, {:id => @azr.to_param, :analyzer => {}}, valid_session
        response.should render_template("edit")
      end
    end

    describe "with no permitted params" do

      before(:each) do
        definitions = {
          "0" => {key: "param1", type: "Integer"},
          "1" => {key: "param2", type: "Float", invalid: 1},
          invalid: 1
        }
        analyzer = {
          name: "analyzerA", type: "on_run", command: "echo",
          parameter_definitions_attributes: definitions,
          auto_run: "no", description: "xxx yyy",
          invalid: 1
        }
        @valid_post_parameter = {id: @azr.to_param, analyzer: analyzer}
      end

      it "update the analyzer but no permitted params are not saved" do
        invalid_analyzer_params = @valid_post_parameter[:analyzer].update(admin_flg: 1)
        invalid_params = @valid_post_parameter
        invalid_params[:analyzer] = invalid_analyzer_params
        post :update, invalid_params, valid_session
        anz = assigns(:analyzer)
        expect(anz.try(:admin_flg)).not_to eq 1
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
        delete :destroy, {id: @azr.to_param, format: 'json'}, valid_session
      }.to change { @sim.reload.analyzers.count }.by(-1)
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
