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
                              run_analysis: true
                              )
    @arn = @run.analyses.first

    @azr2 = FactoryGirl.create(:analyzer,
                               simulator: @sim,
                               type: :on_parameter_set,
                               run_analysis: true
                               )
    @arn2 = @par.analyses.first
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
    end
  end

  describe "POST 'create'" do

    describe "for :on_run type" do

      describe "with valid params" do

        before(:each) do
          @valid_param = {
            run_id: @run.to_param,
            analysis: { analyzer: @azr.to_param},
            parameters: {"param1" => 1, "param2" => 2.0}
          }
        end

        it "creates a new Analysis" do
          expect {
            post :create, @valid_param.update(format: 'json'), valid_session
          }.to change{
            @run.reload.analyses.count
          }.by(1)
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

      describe "with no permitted params" do

        before(:each) do
          @valid_param = {
            run_id: @run.to_param,
            analysis: { analyzer: @azr.to_param },
            parameters: {"param1" => 1, "param2" => 2.0 }
          }
        end

        it "create new analysis but no permitted params are not saved" do
          invalid_analysis_params = @valid_param[:analysis].update(parameters: {"param1"=>2, "param2"=>4.0, invalid: 1})
                                                           .update(status: :finished)
                                                           .update(hostname: "Foo")
                                                           .update(cpu_time: -100.0)
                                                           .update(real_time: -100.0)
                                                           .update(result: {"r1"=>0})
                                                           .update(analyzer_version: "v9999")
                                                           .update(invalid: 1)
          invalid_params = @valid_param.update(invalid: 1)
          invalid_params[:parameters].update(invalid: 1)
          invalid_params[:analysis] = invalid_analysis_params
          expect {
            post :create, invalid_params.update(format: 'json'), valid_session
          }.to change{Analysis.count}.by(1)
          anl = Analysis.last
          expect(anl.parameters).not_to eq ({"param1"=>2, "param2"=>4.0})
          expect(anl.status).not_to eq :finished
          expect(anl.hostname).not_to eq "Foo"
          expect(anl.cpu_time).not_to eq -100.0
          expect(anl.real_time).not_to eq -100.0
          expect(anl.result).not_to eq ({"r1"=>0})
          expect(anl.analyzer_version).not_to eq "v9999"
        end
      end
    end

    describe "for :on_parameter_set type" do

      describe "with valid params" do

        before(:each) do
          @valid_param = {
            parameter_set_id: @par.to_param,
            analysis: { analyzer: @azr2.to_param},
            parameters: {}
          }
        end

        it "creates a new Analysis" do
          expect {
            post :create, @valid_param.update(format: 'json'), valid_session
          }.to change {
            @par.reload.analyses.count
          }.by(1)
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
          @valid_param = {
            parameter_set_id: @par.to_param,
            analysis: { analyzer: @azr2.to_param},
            parameters: {}
          }
        end

        it "create new analysis but no permitted params are not saved" do
          invalid_analysis_params = @valid_param[:analysis].update(parameters: {"param1"=>2, "param2"=>4.0})
                                                           .update(status: :finished)
                                                           .update(hostname: "Foo")
                                                           .update(cpu_time: -100.0)
                                                           .update(real_time: -100.0)
                                                           .update(result: {"r1"=>0})
                                                           .update(analyzer_version: "v9999")
                                                           .update(invalid: 1)
          invalid_params = @valid_param.update(invalid: 1)
          invalid_params[:parameters].update(invalid: 1)
          invalid_params[:analysis] = invalid_analysis_params
          expect {
            post :create, invalid_params.update(format: 'json'), valid_session
          }.to change{Analysis.count}.by(1)
          anl = Analysis.last
          expect(anl.parameters).not_to eq ({"param1"=>2, "param2"=>4.0})
          expect(anl.status).not_to eq :finished
          expect(anl.hostname).not_to eq "Foo"
          expect(anl.cpu_time).not_to eq -100.0
          expect(anl.real_time).not_to eq -100.0
          expect(anl.result).not_to eq ({"r1"=>0})
          expect(anl.analyzer_version).not_to eq "v9999"
        end
      end
    end
  end

  describe "DELETE 'destroy'" do

    it "destroys the analysis when status is neither :failed nor :finished" do
      expect {
        delete :destroy, {id: @arn.to_param, format: 'json'}, valid_session
      }.to change(Analysis, :count).by(-1)
    end

    it "cancels the analysis when status is either :created, :running" do
      @arn.status = :running
      @arn.save!
      expect {
        delete :destroy, {id: @arn.to_param, format: 'json'}, valid_session
      }.to change { Analysis.where(status: :cancelled).count }.by(1)
    end
  end

  describe "GET '_result'" do

    it "returns http success" do
      get '_result', {id: @arn}, valid_session
      expect(response).to be_success
    end
  end
end
