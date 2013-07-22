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
      get 'show', {simulator_id: @sim.id, id: @azr.id }
      response.should be_success
    end

    it "assigns the requested analyzer to @analyzer" do
      get 'show', {simulator_id: @sim.id, id: @azr.id }
      assigns(:analyzer).should eq(@azr)
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
      response.should redirect_to( simulator_url(@sim) )
    end
  end

  describe "GET '_parameters_form'" do

    before(:each) do
      @sim = FactoryGirl.create(:simulator,
                                parameter_sets_count:0, runs_count:0, analyzers_count:2)
      @azr = @sim.analyzers.first
    end

    it "returns http success" do
      get '_parameters_form', {simulator_id: @sim.id, id: @azr.id}
      response.should be_success
    end
  end

end
