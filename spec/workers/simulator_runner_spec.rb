require 'spec_helper'

describe SimulatorRunner do
  
  before(:each) do
    @sim = FactoryGirl.create(:simulator,
                              parameter_sets_count: 1, runs_count: 1)
    @prm = @sim.parameter_sets.first
    @run = @prm.runs.first
  end

  describe ".perform" do

    before(:each) do
      @run_info = {"id" => @run.id, "command" => @run.command, "dir" => @run.dir}
    end

    it "calls Run#command method while performing simulation" do
      @run_info["command"] = "echo hello"
      SimulatorRunner.perform(@run_info)
      File.exist?(@run.dir.join('_stdout.txt')).should be_true
      File.exist?(@run.dir.join('_stderr.txt')).should be_true
      File.open(@run.dir.join('_stdout.txt')).read.should match(/hello/)
    end

    it "write status of Run to '_run_status.json' after simulation successfully finished" do
      @run_info["command"] = "sleep 1"
      SimulatorRunner.perform(@run_info)
      stat_json = @run.dir.join('_run_status.json')
      File.exist?(stat_json).should be_true

      loaded = JSON.load(File.open(stat_json))
      loaded["hostname"].should eq(`hostname`.chomp)
      DateTime.parse(loaded["started_at"]).should be_within(20/28000.0).of(DateTime.now)
      loaded["status"].should eq("finished")
      loaded["cpu_time"].should be_within(0.1).of(0.0)
      loaded["real_time"].should be_within(0.1).of(1.0)
      DateTime.parse(loaded["finished_at"]).should be_within(20/28000.0).of(DateTime.now)
    end

    it "sets status 'failed' if the return code of the command is not zero" do
      @run_info["command"] = "INVALID_CMD"
      SimulatorRunner.perform(@run_info)
      stat_json = @run.dir.join('_run_status.json')
      File.exist?(stat_json).should be_true

      loaded = JSON.load(File.open(stat_json))
      loaded["hostname"].should eq(`hostname`.chomp)
      DateTime.parse(loaded["started_at"]).should be_within(20/28000.0).of(DateTime.now)
      loaded["status"].should eq("failed")
      loaded["cpu_time"].should be_within(0.1).of(0.0)
      loaded["real_time"].should be_within(0.1).of(0.0)
      DateTime.parse(loaded["finished_at"]).should be_within(20/28000.0).of(DateTime.now)
    end

    it "enqueues a job for DataIncluder"
  end
end