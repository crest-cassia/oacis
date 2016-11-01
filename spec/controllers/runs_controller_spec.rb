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
      expect(response).to be_success
    end
  end

  describe "GET 'show'" do

    it "returns http success" do
      get 'show', {id: @run}, valid_session
      expect(response).to be_success
    end

    it "assigns instance variables" do
      get 'show', {id: @run}, valid_session
      expect(assigns(:run)).to eq(@run)
      expect(assigns(:param_set)).to eq(@par)
    end

    it "returns success for json format" do
      get :show, {id: @run, format: :json}, valid_session
      expect(response).to be_success
    end
  end

  describe "POST 'create'" do

    before(:each) do
      @req_param = { parameter_set_id: @par, run: {submitted_to: Host.first.id.to_s}, format: 'json' }
    end

    describe "with valid parameters" do

      it "creates a new run" do
        expect {
          post 'create', @req_param, valid_session
        }.to change(Run.where(parameter_set_id: @par), :count).by(1)
      end

      it "assigns seed specified by request parameter" do
        seed_val = 12345
        @req_param[:run].update({seed: seed_val})
        post 'create', @req_param, valid_session
        new_run = Run.all.to_a.find {|run| run != @run }
        expect(new_run.seed).to eq(seed_val)
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
        expect {
          post 'create', @req_param, valid_session
        }.to raise_error Mongoid::Errors::DocumentNotFound
      end
    end

    describe "with no permitted params" do

      it "create a new run but no permitted params are not saved" do
        invalid_run_params = @req_param[:run].update(status: :finished)
                                     .update(hostname: "Foo")
                                     .update(cpu_time: -100.0)
                                     .update(real_time: -100.0)
                                     .update(result: {"r1"=>0})
                                     .update(simulator_version: "v9999")
                                     .update(job_id: "12345.localhost")
                                     .update(invalid: 1)
        invalid_params = @req_param
        invalid_params[:run] = invalid_run_params
        expect {
          post :create, invalid_params, valid_session
        }.to change{Run.count}.by(1)
        run = Run.order_by(id: :asc).last
        expect(run.status).not_to eq :finished
        expect(run.hostname).not_to eq "Foo"
        expect(run.cpu_time).not_to eq -100.0
        expect(run.real_time).not_to eq -100.0
        expect(run.result).not_to eq ({"r1"=>0})
        expect(run.simulator_version).not_to eq "v9999"
        expect(run.job_id).not_to eq "12345.localhost"
      end
    end

    describe "when preview button is pressed" do

      before(:each) do
        @req_param = {parameter_set_id: @par, run: {omp_threads: 1, mpi_procs: 8, submitted_to: ""}}.merge(preview_button: true)
      end

      it "calls preview method" do
        expect_any_instance_of(RunsController).to receive(:preview).and_call_original
        xhr 'post', 'create', @req_param, valid_session
      end

      it "renders preview" do
        xhr 'post', 'create', @req_param, valid_session
        expect(response).to render_template("preview")
      end

      it "does not create new Run" do
        expect {
          xhr 'post', 'create', @req_param, valid_session
        }.to_not change { Run.count }
      end
    end
  end

  describe "DELETE destroy" do

    it "reduces the number of runs in default scope" do
      expect {
        delete :destroy, {id: @run.to_param, format: 'json'}, valid_session
      }.to change(Run, :count).by(-1)
    end

    it "does not destroy the run" do
      expect {
        delete :destroy, {id: @run.to_param, format: 'json'}, valid_session
      }.to_not change { Run.unscoped.count }
    end
  end
end
