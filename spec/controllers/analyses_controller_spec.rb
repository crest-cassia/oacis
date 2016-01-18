require 'spec_helper'

describe AnalysesController do

  # This should return the minimal set of values that should be in the session
  # in order to pass any filters (e.g. authentication) defined in
  # AnalysesController. Be sure to keep this updated too.
  def valid_session
    {}
  end

  before(:each) do
    @sim = FactoryGirl.create( :simulator,
      parameter_sets_count: 1,
      runs_count: 1,
      analyzers_count: 0,
      )
    @par = @sim.parameter_sets.first
    @run = @par.runs.first

    @azr = FactoryGirl.create(:analyzer,
                              simulator: @sim,
                              type: :on_run,
                              support_mpi: true,
                              support_omp: true,
                              run_analysis: true
                              )
    @arn = @run.analyses.first

    @azr2 = FactoryGirl.create(:analyzer,
                               simulator: @sim,
                               type: :on_parameter_set,
                               support_mpi: true,
                               support_omp: true,
                               run_analysis: true
                               )
    @arn2 = @par.analyses.first

    @host = FactoryGirl.create(:host_with_parameters)
    @azr.executable_on.push @host
    @azr2.executable_on.push @host
  end

  describe "GET 'show'" do

    describe "for :on_run type" do

      it "returns http success" do
        get 'show', {id: @arn}, valid_session
        expect(response).to be_success
      end

      it "assigns instance variables for analysis_on_run" do
        get 'show', {id: @arn}, valid_session
        expect(assigns(:analysis)).to eq(@arn)
      end

      it "returns success for json format" do
        get :show, {id: @arn, format: :json}, valid_session
        expect(response).to be_success
      end
    end

    describe "for :on_parameter_set type" do

      it "returns http success" do
        get 'show', {id: @arn2}, valid_session
        expect(response).to be_success
      end

      it "assigns instance variables" do
        get 'show', {id: @arn2}, valid_session
        expect(assigns(:analysis)).to eq(@arn2)
      end

      it "returns success for json format" do
        get :show, {id: @arn2, format: :json}, valid_session
        expect(response).to be_success
      end
    end
  end

  describe "POST 'create'" do

    describe "for :on_run type" do

      describe "with valid params" do

        before(:each) do
          @valid_param = {
            run_id: @run.to_param,
            analysis: {
              analyzer: @azr.to_param,
              submitted_to: @host.to_param,
              host_parameters: {"param1" => "foo", "param2" => "bar"},
              mpi_procs: 2,
              omp_threads: 8,
              priority: 2,
              parameters: {"param1" => 1, "param2" => 2.0}
            }
          }
        end

        it "creates a new Analysis" do
          analyses_ids = @run.analyses.map(&:id)
          expect {
            post :create, @valid_param.update(format: 'json'), valid_session
          }.to change{
            @run.reload.analyses.count
          }.by(1)
          new_anl_id = @run.reload.analyses.map(&:id) - analyses_ids
          anl = Analysis.find(new_anl_id[0])
          expect(anl.parameters["param1"]).to eq 1
          expect(anl.parameters["param2"]).to eq 2.0
        end

        it "sets fields appropriately" do
          analyses_ids = @run.analyses.map(&:id)
          post :create, @valid_param.update(format: 'json'), valid_session
          new_anl_id = @run.reload.analyses.map(&:id) - analyses_ids
          anl = Analysis.find(new_anl_id[0])
          expect(anl.submitted_to).to eq @host
          expect(anl.host_parameters).to eq @valid_param[:analysis][:host_parameters]
          expect(anl.mpi_procs).to eq 2
          expect(anl.omp_threads).to eq 8
          expect(anl.priority).to eq 2
        end

        it "redirects to 'analysis' tab of Run#show page" do
          post :create, @valid_param.update(format: 'json'), valid_session
          expect(response).not_to redirect_to( run_path(@run, anchor: '!tab-analyses') )
          expect(response).not_to render_template 'create'
        end
      end

      describe "with invalid params" do

        before(:each) do
          @invalid_param = {}    #IMPLEMENT ME
        end

        it "re-renders Run#show template showing errors" do
          skip "not yet implemented"
        end
      end

      describe "with non-permitted params" do

        before(:each) do
          @invalid_param = {
            run_id: @run.to_param,
            analysis: {
              analyzer: @azr.to_param,
              submitted_to: @host.to_param,
              host_parameters: {"param1" => "foo", "param2" => "bar"},
              mpi_procs: 2,
              omp_threads: 8,
              priority: 2,
              parameters: {"param1" => 1, "param2" => 2.0}
            }
          }.update(
            status: :finished,
            hostname: "Foo",
            cpu_time: -100.0,
            real_time: 10.0,
            result: {"r1" => 0},
            analyzer_version: "v9999",
            host_parameters: {"param1"=>"foo", "param2"=>"bar", "param3"=>"baz"},
            parameters: {"param1"=>1, "param2"=>2.0, "param3"=>3}
          )
        end

        it "create new analysis but non-permitted params are not saved" do
          old_ids = Analysis.all.map(&:id)
          expect {
            post :create, @invalid_param.update(format: 'json'), valid_session
          }.to change{Analysis.count}.by(1)
          new_id = (Analysis.all.map(&:id) - old_ids).first
          anl = Analysis.find(new_id)
          expect(anl.status).to eq :created
          expect(anl.hostname).to be_nil
          expect(anl.cpu_time).to be_nil
          expect(anl.real_time).to be_nil
          expect(anl.result).to be_nil
          expect(anl.analyzer_version).to be_nil
          expect(anl.parameters).to eq ({"param1"=>1, "param2"=>2.0})
          expect(anl.host_parameters).to eq ({"param1" => "foo", "param2" => "bar"})
        end
      end
    end

    describe "for :on_parameter_set type" do

      describe "with valid params" do

        before(:each) do
          @valid_param = {
            parameter_set_id: @par.to_param,
            analysis: {
              analyzer: @azr2.to_param,
              submitted_to: @host.to_param,
              host_parameters: {"param1" => "foo", "param2" => "bar"},
              mpi_procs: 2,
              omp_threads: 8,
              priority: 2,
              parameters: {"param1" => 1, "param2" => 2.0}
            }
          }
        end

        it "creates a new Analysis" do
          expect {
            post :create, @valid_param.update(format: 'json'), valid_session
          }.to change {
            @par.reload.analyses.count
          }.by(1)
        end

        it "sets fields appropriately" do
          old_ids = @par.analyses.map(&:id)
          post :create, @valid_param.update(format: 'json'), valid_session
          new_id = ( @par.reload.analyses.map(&:id) - old_ids ).first
          anl = Analysis.find(new_id)
          expect(anl.submitted_to).to eq @host
          expect(anl.host_parameters).to eq @valid_param[:analysis][:host_parameters]
          expect(anl.mpi_procs).to eq 2
          expect(anl.omp_threads).to eq 8
          expect(anl.priority).to eq 2
          expect(anl.parameters).to eq @valid_param[:analysis][:parameters]
        end

        it "redirects to 'analysis' tab of ParameterSet#show page" do
          post :create, @valid_param.update(format: 'json'), valid_session
          expect(response).not_to redirect_to( parameter_set_path(@par, anchor: '!tab-analyses') )
          expect(response).not_to render_template 'create'
        end
      end

      describe "with invalid param" do

        it "re-renders ParameterSet#show template showing errors" do
          skip "not yet implemented"
        end
      end

      describe "with no permitted params" do

        before(:each) do
          @invalid_param = {
            parameter_set_id: @par.to_param,
            analysis: {
              analyzer: @azr2.to_param,
              submitted_to: @host.to_param,
              host_parameters: {"param1" => "foo", "param2" => "bar"},
              mpi_procs: 2,
              omp_threads: 8,
              priority: 2,
              parameters: {"param1" => 1, "param2" => 2.0}
            }
          }.update(
            status: :finished,
            hostname: "Foo",
            cpu_time: -100.0,
            real_time: 10.0,
            result: {"r1" => 0},
            analyzer_version: "v9999",
            host_parameters: {"param1"=>"foo", "param2"=>"bar", "param3"=>"baz"},
            parameters: {"param1"=>1, "param2"=>2.0, "param3"=>3}
          )
        end

        it "create new analysis but no permitted params are not saved" do
          old_analyses = Analysis.all.to_a
          expect {
            post :create, @invalid_param.update(format: 'json'), valid_session
          }.to change{Analysis.count}.by(1)
          anl = (Analysis.all.to_a - old_analyses).first
          expect(anl.status).to eq :created
          expect(anl.hostname).to be_nil
          expect(anl.cpu_time).to be_nil
          expect(anl.real_time).to be_nil
          expect(anl.result).to be_nil
          expect(anl.analyzer_version).to be_nil
          expect(anl.parameters).to eq ({"param1"=>1, "param2"=>2.0})
          expect(anl.host_parameters).to eq ({"param1" => "foo", "param2" => "bar"})
        end
      end
    end
  end

  describe "DELETE 'destroy'" do

    it "destroys the number of analyses in default scope" do
      expect {
        delete :destroy, {id: @arn.to_param, format: 'json'}, valid_session
      }.to change(Analysis, :count).by(-1)
    end

    it "does not destroy the analysis" do
      expect {
        delete :destroy, {id: @arn.to_param, format: 'json'}, valid_session
      }.to_not change { Analysis.unscoped.count }
    end
  end

  describe "GET '_result'" do

    it "returns http success" do
      get '_result', {id: @arn}, valid_session
      expect(response).to be_success
    end
  end
end
