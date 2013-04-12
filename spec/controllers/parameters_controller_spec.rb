require 'spec_helper'

describe ParametersController do

  # This should return the minimal set of values that should be in the session
  # in order to pass any filters (e.g. authentication) defined in
  # ParametersController. Be sure to keep this updated too.
  def valid_session
    {}
  end
  
  describe "GET 'show'" do

    it "returns http success" do
      sim = FactoryGirl.create(:simulator)
      get 'show', {id: sim.parameters.first}, valid_session
      response.should be_success
    end

    it "assigns instance variables" do
      sim = FactoryGirl.create(:simulator)
      prm = sim.parameters.first
      get 'show', {id: prm}, valid_session
      assigns(:parameter).should eq(prm)
      assigns(:simulator).should eq(sim)
      assigns(:parameter_keys).should eq(["L","T"])
      assigns(:runs).first.should be_a(Run)
    end

    it "paginates list of runs" do
      sim = FactoryGirl.create(:simulator, runs_count: 100)
      prm = sim.parameters.first
      get 'show', {id: prm, page: 1}, valid_session
      assigns(:runs).count.should == 100
      assigns(:runs).to_a.size.should == 25
    end
  end
end
