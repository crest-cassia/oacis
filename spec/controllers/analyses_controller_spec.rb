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
        response.should be_success
      end

      it "assigns instance variables for analysis_on_run" do
        get 'show', {id: @arn}, valid_session
        assigns(:analysis).should eq(@arn)
      end
    end

    describe "for :on_parameter_set type" do

      it "returns http success" do
        get 'show', {id: @arn2}, valid_session
        response.should be_success
      end

      it "assigns instance variables" do
        get 'show', {id: @arn2}, valid_session
        assigns(:analysis).should eq(@arn2)
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
            parameters: {"param1" => 1, "param2" => 2.0},
            format: 'json'
          }
        end

        it "creates a new Analysis" do
          expect {
            post :create, @valid_param, valid_session
          }.to change{
            @run.reload.analyses.count
          }.by(1)
        end

        it "redirects to 'analysis' tab of Run#show page" do
          post :create, @valid_param, valid_session
          response.should_not redirect_to( run_path(@run, anchor: '!tab-analyses') )
          response.should_not render_template 'create'
        end
      end

      describe "with invalid params" do

        before(:each) do
          @invalid_param = {
            run_id: @run.to_param,
            analysis: { analyzer: @azr.to_param},
            parameters: {"param1" => 1, "param2" => 2.0},
            result: "abc",
            status: :running,
            format: 'json'
          }
        end

        it "re-renders Run#show template showing errors" do
          skip "not yet implemented"
        end

        it "result is not an accessible field" do
          expect {
            post :create, @invalid_param, valid_session
          }.to change{
            @run.reload.analyses.count
          }.by(1)
          @run.analyses.last.result.should be_nil
          @run.analyses.last.status.should_not eq :running
        end
      end
    end

    describe "for :on_parameter_set type" do

      describe "with valid params" do

        before(:each) do
          @valid_param = {
            parameter_set_id: @par.to_param,
            analysis: { analyzer: @azr2.to_param},
            parameters: {},
            format: 'json'
          }
        end

        it "creates a new Analysis" do
          expect {
            post :create, @valid_param, valid_session
          }.to change {
            @par.reload.analyses.count
          }.by(1)
        end

        it "redirects to 'analysis' tab of ParameterSet#show page" do
          post :create, @valid_param, valid_session
          response.should_not redirect_to( parameter_set_path(@par, anchor: '!tab-analyses') )
          response.should_not render_template 'create'
        end
      end

      describe "with invalid param" do

        it "re-renders ParameterSet#show template showing errors" do
          skip "not yet implemented"
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
      response.should be_success
    end
  end
end
