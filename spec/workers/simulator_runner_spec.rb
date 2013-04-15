require 'spec_helper'

describe SimulatorRunner do
  
  before(:each) do
    @sim = FactoryGirl.create(:simulator)
    @prm = @sim.parameters.first
    @run = @prm.runs.first
  end

  it "updates status of Run before performing simulation" do
    hostname = `hostname`.chomp
    SimulatorRunner.before_perform(@run.id)

    run = Run.find(@run.id)
    run.status.should == :running
    run.hostname.should == hostname
    run.started_at.should_not be_nil
  end

  it "calls Run#command method while calling .perform method" do
    SimulatorRunner.before_perform(@run.id)
    cmd = @run.command
    @run.should_receive(:command).and_return(cmd)
    Run.stub!(:find).and_return(@run)

    SimulatorRunner.perform(@run.id)
    File.exist?(@run.dir.join('_stdout.txt')).should be_true
    File.exist?(@run.dir.join('_stderr.txt')).should be_true
  end

  it "updates status of Run after performing simulation" do
    SimulatorRunner.before_perform(@run.id)
    SimulatorRunner.perform(@run.id)

    run = Run.find(@run)
    run.status.should == :finished
    run.cpu_time.should_not be_nil
    run.real_time.should_not be_nil
    run.finished_at.should_not be_nil
    run.included_at.should_not be_nil
  end
end