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
      @sim = FactoryBot.create(:simulator,
                                parameter_sets_count:0, runs_count:0, analyzers_count:2)
      @azr = @sim.analyzers.first
    end

    it "returns http success" do
      get 'show', {id: @azr }
      expect(response).to be_success
    end

    it "assigns the requested analyzer to @analyzer" do
      get 'show', {id: @azr }
      expect(assigns(:analyzer)).to eq(@azr)
    end

    it "returns success for json format" do
      get :show, {id: @azr, format: :json}, valid_session
      expect(response).to be_success
    end
  end

  describe "GET new" do

    before(:each) do
      @sim = FactoryBot.create(:simulator,
                                parameter_sets_count: 0, runs_count: 0, analyzers_count: 0)
    end

    it "assigns a new simulator as @simulator" do
      get :new, {simulator_id: @sim.to_param}, valid_session
      expect(assigns(:analyzer)).to be_a_new(Analyzer)
    end
  end

  describe "GET edit" do

    before(:each) do
      @sim = FactoryBot.create(:simulator,
                                parameter_sets_count: 0, runs_count: 0, analyzers_count: 1)
      @azr = @sim.analyzers.first
    end

    it "assigns the requested analyzer as @analyzer" do
      get :edit, {:id => @azr.to_param}, valid_session
      expect(assigns(:analyzer)).to eq(@azr)
    end
  end


  describe "POST create" do

    before(:each) do
      @sim = FactoryBot.create(:simulator,
                                parameter_sets_count: 0, runs_count: 0, analyzers_count: 0)
    end

    describe "with valid params" do

      before(:each) do
        @host = FactoryBot.create(:host)
        definitions = {
          "0" => {key: "param1", type: "Integer"},
          "1" => {key: "param2", type: "Float"}
        }
        analyzer = {
          name: "analyzerA", type: "on_run", command: "echo",
          parameter_definitions_attributes: definitions,
          auto_run: "no",
          files_to_copy: "abc.txt\ndef.txt",
          description: "xxx yyy",
          support_input_json: "1", support_mpi: "1", support_omp: "0",
          pre_process_script: "echo preprocess",
          local_pre_process_script: "echo local_preprocess",
          executable_on_ids: [@host.id.to_s],
          auto_run_submitted_to: @host.id.to_s
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
        azr = Analyzer.order_by(id: :asc).last
        expect(azr.name).to eq "analyzerA"
        expect(azr.type).to eq :on_run
        expect(azr.command).to eq "echo"
        expect(azr.auto_run).to eq :no
        expect(azr.files_to_copy).to eq "abc.txt\ndef.txt"
        expect(azr.description).to eq "xxx yyy"
        expect(azr.parameter_definition_for("param1").type).to eq "Integer"
        expect(azr.parameter_definition_for("param2").type).to eq "Float"
        expect(azr.support_input_json).to be_truthy
        expect(azr.support_mpi).to be_truthy
        expect(azr.support_omp).to be_falsey
        expect(azr.pre_process_script).to eq("echo preprocess")
        expect(azr.local_pre_process_script).to eq("echo local_preprocess")
        expect(azr.executable_on).to eq [@host]
        expect(azr.auto_run_submitted_to).to eq @host
      end

      it "assigns auto_run_host_group attribute" do
        hg = FactoryBot.create(:host_group)
        @valid_post_parameter[:analyzer][:auto_run_submitted_to] = hg.id.to_s
        post :create, @valid_post_parameter, valid_session
        azr = Analyzer.desc(:created_at).first
        expect( azr.auto_run_submitted_to ).to be nil
        expect( azr.auto_run_host_group ).to eq hg
      end

      it "assigns a newly created analyzer as @analyzer" do
        post :create, @valid_post_parameter, valid_session
        expect(assigns(:analyzer)).to be_a(Analyzer)
        expect(assigns(:analyzer)).to be_persisted
      end

      it "redirects to the created analyzer" do
        post :create, @valid_post_parameter, valid_session
        expect(response).to redirect_to(Analyzer.order_by(id: :asc).last)
      end
    end

    describe "with invalid params" do

      it "assigns a newly created but unsaved analyzer as @analyzer" do
        expect {
          post :create, {simulator_id: @sim.id, analyzer: {}}, valid_session
          expect(assigns(:analyzer)).to be_a_new(Analyzer)
        }.to_not change(Analyzer, :count)
      end

      it "re-renders the 'new' template" do
        # Trigger the behavior that occurs when invalid params are submitted
        post :create, {simulator_id: @sim.id, analyzer: {}}, valid_session
        expect(response).to render_template("new")
      end
    end

    describe "with non-permitted params" do

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

      it "create a new analyzer but non-permitted params are not saved" do
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
      @sim = FactoryBot.create(:simulator,
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
          auto_run: "no",
          files_to_copy: "abc.txt\ndef.txt",
          description: "xxx yyy",
          support_input_json: "1", support_mpi: "1", support_omp: "0",
          pre_process_script: "echo preprocess",
          local_pre_process_script: "echo local_preprocess",
          executable_on: [],
          auto_run_submitted_to: ''
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
        expect(assigns(:analyzer)).to eq(@azr)
      end

      it "redirects to the analyzer" do
        put :update, {:id => @azr.to_param, :analyzer => @valid_post_parameter}, valid_session
        expect(response).to redirect_to(@azr)
      end
    end

    describe "with invalid params" do

      it "assigns the analyzer as @analyzer" do
        allow_any_instance_of(Analyzer).to receive(:update_attributes).and_return(false)
        put :update, {:id => @azr.to_param, :analyzer => {}}, valid_session
        expect(assigns(:analyzer)).to eq(@azr)
      end

      it "re-renders the 'edit' template" do
        allow_any_instance_of(Analyzer).to receive(:update_attributes).and_return(false)
        put :update, {:id => @azr.to_param, :analyzer => {}}, valid_session
        expect(response).to render_template("edit")
      end
    end

    describe "with non-permitted params" do

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

      it "update the analyzer but non-permitted params are not saved" do
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
      @sim = FactoryBot.create(:simulator, parameter_sets_count: 0, analyzers_count: 1)
      @azr = @sim.analyzers.first
    end

    it "reduces the number of analyzers in default scope" do
      expect {
        delete :destroy, {id: @azr.to_param, format: 'json'}, valid_session
      }.to change { @sim.reload.analyzers.count }.by(-1)
    end

    it "does not destroy the analyzer" do
      expect {
        delete :destroy, {id: @azr.to_param, format: 'json'}, valid_session
      }.to_not change { @sim.reload.analyzers.unscoped.count }
    end
  end

  describe "GET '_parameters_form'" do

    before(:each) do
      @sim = FactoryBot.create(:simulator,
                                parameter_sets_count:0, runs_count:0, analyzers_count:2)
      @azr = @sim.analyzers.first
    end

    it "returns http success" do
      get '_parameters_form', {id: @azr.id}
      expect(response).to be_success
    end
  end

  describe "GET _host_parameters_field" do

    before(:each) do
      @host = FactoryBot.create(:host_with_parameters)
      @sim = FactoryBot.create(:simulator, parameter_sets_count: 0, analyzers_count: 1)
      @azr = @sim.analyzers.first
      @azr.executable_on.push(@host)
    end

    it "returns http success" do
      valid_param = {id: @azr.to_param, host_id: @host.to_param}
      get :_host_parameters_field, valid_param, valid_session
      expect(response).to be_success
    end

    it "returns http success even if host_id is not found" do
      param = {id: @azr.to_param, host_id: "DO_NOT_EXIST"}
      get :_host_parameters_field, param, valid_session
      expect(response).to be_success
    end
  end

  describe "GET _default_mpi_omp" do

    before(:each) do
      @host = FactoryBot.create(:host_with_parameters)
      @sim = FactoryBot.create(:simulator,
                                parameter_sets_count: 0, analyzers_count: 1)
      @azr = @sim.analyzers.first
      @azr.executable_on.push(@host)
    end

    it "returns http success" do
      valid_param = {id: @azr.to_param, host_id: @host.to_param}
      get :_default_mpi_omp, valid_param, valid_session
      expect(response).to be_success
    end

    it "does not cause an error even when host is not found" do
      param = {id: @azr.to_param, host_id: 'DO_NOT_EXIST'}
      get :_default_mpi_omp, param, valid_session
      expect(response).to be_success
    end

    context "when default_mpi_procs and/or defualt_omp_threads are set" do

      before(:each) do
        @azr.update_attribute(:default_mpi_procs, {@host.id.to_s => 8})
        @azr.update_attribute(:default_omp_threads, {@host.id.to_s => 4})
      end

      it "returns mpi_procs and omp_threads in json" do
        valid_param = {id: @azr.to_param, host_id: @host.to_param}
        get :_default_mpi_omp, valid_param, valid_session
        expect(response.header['Content-Type']).to include 'application/json'
        parsed = JSON.parse(response.body)
        expect(parsed).to eq ({'mpi_procs' => 8, 'omp_threads' => 4})
      end
    end

    context "when default_mpi_procs or default_omp_threads is not set" do

      before(:each) do
        @azr.update_attribute(:default_mpi_procs, {})
        @azr.update_attribute(:default_omp_threads, {})
      end

      it "returns mpi_procs and omp_threads in json" do
        valid_param = {id: @azr.to_param, host_id: @host.to_param}
        get :_default_mpi_omp, valid_param, valid_session
        expect(response.header['Content-Type']).to include 'application/json'
        parsed = JSON.parse(response.body)
        expect(parsed).to eq ({'mpi_procs' => 1, 'omp_threads' => 1})
      end
    end
  end
end
