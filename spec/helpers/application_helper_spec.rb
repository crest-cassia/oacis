require 'spec_helper'

describe ApplicationHelper, type: :helper do

  helper ApplicationHelper

  describe "#shortened_id" do

    it "returns shortened id" do
      id_org = "51d0f8e5899e53cf2e00000a"
      helper.shortened_id(id_org).should eq "0f8e..00a"
    end
  end
end