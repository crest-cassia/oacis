require 'spec_helper'

describe JobSubmitter do

  describe ".perform" do

    before(:each) do
      @host = FactoryGirl.create(:localhost)
      @temp_dir = Pathname.new('__temp__')
      FileUtils.mkdir_p(@temp_dir)
      @host.work_base_dir = @temp_dir.expand_path
      @host.save!

      @sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 1)
      @sim.executable_on.push @host
      @sim.save!

      @logger = Logger.new($stderr)
    end

    after(:each) do
      FileUtils.rm_rf(@temp_dir) if File.directory?(@temp_dir)
    end

    it "enqueues a job to remote host" do
      expect {
        JobSubmitter.perform(@logger)
      }.to change { Run.where(status: :submitted).count }.by(1)
    end

    it "do nothing if there is no 'created' jobs" do
      @sim.runs.first.update_attribute(:status, :finished)
      expect {
        JobSubmitter.perform(@logger)
      }.to_not raise_error
    end

    it "does not create SSH connection if there is no submittable jobs" do
      @sim.runs.first.update_attribute(:status, :finished)
      Host.any_instance.should_not_receive(:start_ssh)
      JobSubmitter.perform(@logger)
    end

    it "do nothing if there is no 'enabled' hosts" do
      @host.update_attribute(:status, :disabled)
      expect {
        JobSubmitter.perform(@logger)
      }.to change { Run.where(status: :created).count }.by(0)
      expect {
        JobSubmitter.perform(@logger)
      }.to_not raise_error
    end

    it "enqueus jobs to remote host in order of priorities on runs" do
      run = @sim.parameter_sets.first.runs.create(priority: 0, submitted_to: @host.to_param)
      run.save!
      expect {
        JobSubmitter.perform(@logger)
      }.to change { Run.where(status: :submitted, priority: 0).count }.by(1)
      Run.where(status: :submitted, priority: 1).count.should eq 0
    end

    it "does not enqueue a job until polling interval has passed since the last submission" do
      skip "not yet implemented"
    end
  end
end
