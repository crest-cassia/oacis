require 'spec_helper'

describe ParametersController do

  describe "GET 'show'" do
    it "returns http success" do
      sim = FactoryGirl.create(:simulator)
      get 'show', id: sim.parameters.first, simulator_id: sim
      response.should be_success
    end
  end
end
