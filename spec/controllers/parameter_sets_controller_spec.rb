require 'spec_helper'

describe ParameterSetsController do

  # This should return the minimal set of values that should be in the session
  # in order to pass any filters (e.g. authentication) defined in
  # ParameterSetsController. Be sure to keep this updated too.
  def valid_session
    {}
  end
  
  describe "GET 'show'" do

    it "returns http success" do
      sim = FactoryGirl.create(:simulator)
      get 'show', {id: sim.parameter_sets.first}, valid_session
      response.should be_success
    end

    it "assigns instance variables" do
      sim = FactoryGirl.create(:simulator)
      prm = sim.parameter_sets.first
      get 'show', {id: prm}, valid_session
      assigns(:param_set).should eq(prm)
      assigns(:simulator).should eq(sim)
      assigns(:parameter_keys).should eq(["L","T"])
      assigns(:runs).first.should be_a(Run)
    end

    it "paginates list of runs" do
      sim = FactoryGirl.create(:simulator, parameter_sets_count:1, runs_count: 30)
      prm = sim.parameter_sets.first
      get 'show', {id: prm, page: 1}, valid_session
      assigns(:runs).count.should == 30
      assigns(:runs).to_a.size.should == 25
    end
  end
end
