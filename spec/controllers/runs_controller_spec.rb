require 'spec_helper'

describe RunsController do

  before(:each) do
    @sim = FactoryBot.create(:simulator,
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
      get 'index', params: {}
      expect(response).to be_successful
    end
  end

  describe "GET 'show'" do

    it "returns http success" do
      get 'show', params: {id: @run}
      expect(response).to be_successful
    end

    it "assigns instance variables" do
      get 'show', params: {id: @run}
      expect(assigns(:run)).to eq(@run)
      expect(assigns(:param_set)).to eq(@par)
    end

    it "returns success for json format" do
      get :show, params: {id: @run, format: :json}
      expect(response).to be_successful
    end
  end

  describe "GET _jobs_table" do
    it "returns json record without filtering" do
      get :_jobs_table, params: {run_status: ['created']}
      expect(JSON.parse(response.body)['recordsTotal']).to eq(1)
    end

    it "returns json record with filtering" do
      get :_jobs_table, params: {run_status: ['created'], simulator_id: 'dummy'}
      expect(JSON.parse(response.body)['recordsTotal']).to eq(0)
    end
  end

  describe "POST 'create'" do

    before(:each) do
      @req_param = { parameter_set_id: @par, run: {submitted_to: Host.first.id.to_s}, format: 'json' }
    end

    describe "with valid parameters" do

      it "creates a new run" do
        expect {
          post 'create', params: @req_param
        }.to change(Run.where(parameter_set_id: @par), :count).by(1)
      end

      it "create multiple items when params[num_runs] is given" do
        num_runs = 3
        expect {
          post 'create', params: @req_param.update(num_runs: num_runs)
        }.to change(Run.where(parameter_set_id: @par), :count).by(num_runs)
      end

      it "assigns HostGroup" do
        hg = FactoryBot.create(:host_group)
        @req_param[:run] = {submitted_to: hg.id.to_s}
        post 'create', params: @req_param
        new_run = Run.desc(:created_at).first
        expect( new_run.submitted_to ).to be_nil
        expect( new_run.host_group ).to eq hg
      end
    end

    describe "with invalid parameters" do

      it "raises an error when the ParameterSet is not found" do
        @req_param.update(parameter_set_id: 1234)
        expect {
          post 'create', params: @req_param
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
          post :create, params: invalid_params
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
        @req_param = {parameter_set_id: @par, run: {omp_threads: 1, mpi_procs: 8, submitted_to: Host.first.id.to_s}}.merge(preview_button: true)
      end

      it "calls preview method" do
        expect_any_instance_of(RunsController).to receive(:preview).and_call_original
        post 'create', params: @req_param, xhr: true
      end

      it "renders preview" do
        post 'create', params: @req_param, xhr: true
        expect(response).to render_template("preview")
      end

      it "does not create new Run" do
        expect {
          post 'create', params: @req_param, xhr: true
        }.to_not change { Run.count }
      end
    end
  end
end
