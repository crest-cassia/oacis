require 'spec_helper'

describe ApplicationHelper, type: :helper do

  helper ApplicationHelper

  describe "#shortened_id" do

    it "returns shortened id" do
      id_org = "51d0f8e5899e53cf2e00000a"
      helper.shortened_id(id_org).should eq "0f8e..00a"
    end
  end

  describe "#shortened_job_id" do

    it "returns shortened job id" do
      id_org = "51d0f8e5899e53cf2e00000a.sh"
      helper.shortened_job_id(id_org).should eq "51d0f8.."
    end

    it "does not cause error when nil is given" do
      id_org = nil
      helper.shortened_job_id(id_org).should eq ""
    end
  end
end
