require 'spec_helper'

describe JobSubmitter do

  describe ".perform" do

    before(:each) do
      @host = FactoryGirl.create(:localhost)
      @temp_dir = Pathname.new('__temp__')
      FileUtils.mkdir_p(@temp_dir)
      @host.work_base_dir = @temp_dir.expand_path
      @host.save!

      @logger = Logger.new($stderr)
    end

    after(:each) do
      FileUtils.rm_rf(@temp_dir) if File.directory?(@temp_dir)
    end

    it "enqueues a job to remote host" do
      @sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 1)
      @sim.executable_on.push @host
      @sim.save!
      expect {
        JobSubmitter.perform(@logger)
      }.to change { Run.where(status: :submitted).count }.by(1)
    end

    it "do nothing if there is no 'created' jobs" do
      @sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 0)
      expect {
        JobSubmitter.perform(@logger)
      }.to_not raise_error
    end

    it "enqueus jobs to remote host in order of the priority on the run" do
      @sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 1)
      @sim.executable_on.push @host
      @sim.save!
      run = @sim.parameter_sets.first.runs.create(priority: :high, submitted_to: @host.to_param)
      run.save!
      expect {
        JobSubmitter.perform(@logger)
      }.to change { Run.where(status: :submitted, priority: :high).count }.by(1)
      Run.where(status: :submitted, priority: :normal).count.should eq 0
    end
  end
end
