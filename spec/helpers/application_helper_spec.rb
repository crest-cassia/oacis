require 'spec_helper'

describe ApplicationHelper, type: :helper do

  helper ApplicationHelper

  describe "#shortened_id" do

    it "returns shortened id" do
      id_org = "51d0f8e5899e53cf2e031001"
      expect(helper.shortened_id(id_org)).to eq "8e5001"
    end
  end

  describe "#shortened_job_id" do

    it "returns shortened job id" do
      id_org = "51d0f8e5899e53cf2e00000a.sh"
      expect(helper.shortened_job_id(id_org)).to eq "51d0f8.."
    end

    it "does not cause error when nil is given" do
      id_org = nil
      expect(helper.shortened_job_id(id_org)).to eq ""
    end
  end
end
