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
                                parameter_sets_count:0, runs_count:0, analyzers_count:2, parameter_set_queries_count:0)
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

  describe "GET '_parameters_form'" do

    before(:each) do
      @sim = FactoryGirl.create(:simulator,
                                parameter_sets_count:0, runs_count:0, analyzers_count:2, parameter_set_queries_count:0)
      @azr = @sim.analyzers.first
    end

    it "returns http success" do
      get '_parameters_form', {simulator_id: @sim.id, id: @azr.id}
      response.should be_success
    end
  end

end
