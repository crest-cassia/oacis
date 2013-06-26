require 'spec_helper'

describe JobScriptUtil do

  describe ".script_for" do

    before(:each) do
      @sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 1)
      @run = @sim.parameter_sets.first.runs.first
      @host = FactoryGirl.create(:localhost, work_base_dir: "./__work__")
    end

    it "returns a job script string" do
      str = JobScriptUtil.script_for(@run, @host)
      str.should be_a(String)
      File.open("test.sh", 'w') {|f| f.print str }
    end
  end
end