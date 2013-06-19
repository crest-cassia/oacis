require 'spec_helper'

describe AnalysisRunsController do

  # This should return the minimal set of values that should be in the session
  # in order to pass any filters (e.g. authentication) defined in
  # AnalysisRunsController. Be sure to keep this updated too.
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
    @arn = @run.analysis_runs.first

    @azr2 = FactoryGirl.create(:analyzer,
                               simulator: @sim,
                               type: :on_parameter_set,
                               run_analysis: true
                               )
    @arn2 = @par.analysis_runs.first
  end

  describe "GET 'show'" do

    describe "for :on_run type" do

      it "returns http success" do
        get 'show', {run_id: @run, id: @arn}, valid_session
        response.should be_success
      end

      it "assigns instance variables for analysis_on_run" do
        get 'show', {run_id: @run, id: @arn}, valid_session
        assigns(:analysis_run).should eq(@arn)
      end
    end

    describe "for :on_parameter_set type" do

      it "returns http success" do
        get 'show', {parameter_set_id: @par, id: @arn2}, valid_session
        response.should be_success
      end

      it "assigns instance variables" do
        get 'show', {parameter_set_id: @par, id: @arn2}, valid_session
        assigns(:analysis_run).should eq(@arn2)
      end
    end
  end

  describe "POST 'create'" do

    describe "for :on_run type" do

      describe "with valid params" do

        before(:each) do
          @valid_param = {
            run_id: @run.to_param,
            analysis_run: { analyzer: @azr.to_param},
            parameters: {"param1" => 1, "param2" => 2.0}
          }
        end

        it "creates a new AnalysisRun" do
          expect {
            post :create, @valid_param, valid_session
          }.to change{
            @run.reload.analysis_runs.count
          }.by(1)
        end

        it "redirects to the created analysis_run" do
          post :create, @valid_param, valid_session
          @run.reload
          response.should redirect_to( analysis_run_path(@run.analysis_runs.last) )
        end
      end

      describe "with invalid params" do

        before(:each) do
          @invalid_param = {}   #IMPLEMENT ME
        end

        it "re-renders Run#show template showing errors" do
          pending "not yet implemented"
        end
      end
    end

    describe "for :on_parameter_set type" do

      describe "with valid params" do

        before(:each) do
          @valid_param = {
            parameter_set_id: @par.to_param,
            analysis_run: { analyzer: @azr.to_param},
            parameters: {}
          }
        end

        it "creates a new AnalysisRun" do
          expect {
            post :create, @valid_param, valid_session
          }.to change {
            @par.reload.analysis_runs.count
          }.by(1)
        end

        it "redirects to the created analysis_run" do
          post :create, @valid_param, valid_session
          @par.reload
          response.should redirect_to( analysis_run_path(@par.analysis_runs.last) )
        end
      end

      describe "with invalid param" do

        it "re-renders ParameterSet#show template showing errors" do
          pending "not yet implemented"
        end
      end
    end
  end

end
