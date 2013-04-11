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
      get 'show', {id: sim.parameters.first, simulator_id: sim}, valid_session
      response.should be_success
    end
  end
end
