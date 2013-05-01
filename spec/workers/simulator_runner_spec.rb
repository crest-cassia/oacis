require 'spec_helper'

describe SimulatorRunner do
  
  before(:each) do
    @sim = FactoryGirl.create(:simulator,
                              parameter_sets_count: 1, runs_count: 1)
    @prm = @sim.parameter_sets.first
    @run = @prm.runs.first
  end

  describe ".before_perform" do

    it "updates status of Run before performing simulation" do
      hostname = `hostname`.chomp
      SimulatorRunner.before_perform(@run.id)

      run = Run.find(@run.id)
      run.status.should == :running
      run.hostname.should == hostname
      run.started_at.should_not be_nil
    end
  end

  describe ".perform" do

    before(:each) do
      SimulatorRunner.before_perform(@run.id)
    end

    it "calls Run#command method while performing simulation" do
      cmd = @run.command
      @run.should_receive(:command).and_return(cmd)
      Run.stub!(:find).and_return(@run)

      SimulatorRunner.perform(@run.id)
      File.exist?(@run.dir.join('_stdout.txt')).should be_true
      File.exist?(@run.dir.join('_stderr.txt')).should be_true
    end

    it "updates status of Run to 'finished' after simulation successfully finished" do
      SimulatorRunner.perform(@run.id)

      run = Run.find(@run)
      run.status.should == :finished
      run.cpu_time.should_not be_nil
      run.real_time.should_not be_nil
      run.finished_at.should_not be_nil
      run.included_at.should_not be_nil
    end

    it "raises an exception if the return code of the command is not zero" do
      sim = @run.parameter_set.simulator
      sim.execution_command = "INVALID_CMD"
      sim.save!

      lambda {
        SimulatorRunner.perform(@run.id)
      }.should raise_error
    end
  end

  describe ".on_failure" do

    before(:each) do
      SimulatorRunner.before_perform(@run.id)
    end

    it "updates status to 'failed' on failure" do
      SimulatorRunner.on_failure(StandardError.new, @run.id)

      run = Run.find(@run)
      run.status.should == :failed
    end
  end
end