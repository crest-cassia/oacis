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
      response.should be_success
    end
  end

  describe "GET 'show'" do

    it "returns http success" do
      get 'show', {id: @run}, valid_session
      response.should be_success
    end

    it "assigns instance variables" do
      get 'show', {id: @run}, valid_session
      assigns(:run).should eq(@run)
      assigns(:param_set).should eq(@par)
    end

    it "assigns 'analyses' variable" do
      get 'show', {id: @run}, valid_session
      assigns(:analyses).should eq(@run.analyses)
    end
  end

  describe "POST 'create'" do

    before(:each) do
      @req_param = {parameter_set_id: @par}
    end

    describe "with valid parameters" do

      it "creates a new run" do
        expect {
          post 'create', @req_param, valid_session
        }.to change(Run.where(parameter_set_id: @par), :count).by(1)
      end

      it "assigns seed specified by request parameter" do
        seed_val = 12345
        @req_param.update(run: {seed: seed_val})
        post 'create', @req_param, valid_session
        Run.where(parameter_set_id: @par).last.seed.should == seed_val
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
        lambda {
          post 'create', @req_param, valid_session
        }.should raise_error
      end

      it "fails with a duplicated seed" do
        seed_val = @par.runs.first.seed
        @req_param.update(run: {seed: seed_val})
        expect {
          post 'create', @req_param, valid_session
        }.to change(Run, :count).by(0)
      end
    end

    describe "when preview button is pressed" do

      before(:each) do
        @req_param = {parameter_set_id: @par}.merge(preview_button: true)
      end

      it "calls preview method" do
        RunsController.any_instance.should_receive(:preview).and_call_original
        xhr 'post', 'create', @req_param, valid_session
      end

      it "renders preview" do
        xhr 'post', 'create', @req_param, valid_session
        response.should render_template("preview")
      end

      it "does not create new Run" do
        expect {
          xhr 'post', 'create', @req_param, valid_session
        }.to_not change { Run.count }
      end
    end
  end

  describe "DELETE destroy" do

    it "destroys the run when status is neither submitted nor running" do
      expect {
        delete :destroy, {id: @run.to_param}, valid_session
      }.to change(Run, :count).by(-1)
    end

    it "cancels the run when status is either submitted or running" do
      @run.status = :running
      @run.save!
      expect {
        delete :destroy, {id: @run.to_param}, valid_session
      }.to change { Run.where(status: :cancelled).count }.by(1)
    end
  end
end
