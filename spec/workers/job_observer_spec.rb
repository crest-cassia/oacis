require 'spec_helper'

describe JobObserver do

  describe ".perform" do

    before(:each) do
      @sim = FactoryGirl.create(:simulator,
                                parameter_sets_count: 1, runs_count: 1)
      @temp_dir = Pathname.new('__temp__')
      FileUtils.mkdir_p(@temp_dir)
      @host = @sim.executable_on.where(name: "localhost").first
      @host.work_base_dir = @temp_dir.expand_path
      @host.save!

      @run = @sim.parameter_sets.first.runs.first
      @run.status = :submitted
      @run.submitted_to = @host
      @run.save!

      @logger = Logger.new( @temp_dir.join('log.txt') )
    end

    after(:each) do
      FileUtils.rm_r(@temp_dir) if File.directory?(@temp_dir)
    end

    it "do observe_host if host status is 'enabled'" do
      expect(JobObserver).to receive(:observe_host).and_return(nil)
      JobObserver.perform(@logger)
    end

    it "do nothing if host status is 'disabled'" do
      @host.update_attribute(:status, :disabled)
      expect(JobObserver).not_to receive(:observe_host)
      JobObserver.perform(@logger)
    end
  end

  describe ".observe_host" do

    before(:each) do
      @sim = FactoryGirl.create(:simulator,
                                parameter_sets_count: 1, runs_count: 1)
      @temp_dir = Pathname.new('__temp__')
      FileUtils.mkdir_p(@temp_dir)
      @host = @sim.executable_on.where(name: "localhost").first
      @host.work_base_dir = @temp_dir.expand_path
      @host.save!

      @run = @sim.parameter_sets.first.runs.first
      @run.status = :submitted
      @run.submitted_to = @host
      @run.save!

      @logger = Logger.new( @temp_dir.join('log.txt') )
    end

    after(:each) do
      FileUtils.rm_r(@temp_dir) if File.directory?(@temp_dir)
    end

    it "do nothing if remote_status is 'submitted'" do
      expect_any_instance_of(RemoteJobHandler).to receive(:remote_status).and_return(:submitted)
      JobObserver.__send__(:observe_host, @host, @logger)
      expect(@run.reload.status).to eq :submitted
    end

    it "update status to 'running' when remote_status of Run is 'running'" do
      expect_any_instance_of(RemoteJobHandler).to receive(:remote_status).and_return(:running)
      JobObserver.__send__(:observe_host, @host, @logger)
      expect(@run.reload.status).to eq :running
    end

    it "include remote data and update status to 'finished' or 'failed'" do
      expect_any_instance_of(RemoteJobHandler).to receive(:remote_status).and_return(:includable)
      expect(JobIncluder).to receive(:include_remote_job) do |host, run|
        expect(run.id).to eq @run.id
      end
      JobObserver.__send__(:observe_host, @host, @logger)
    end

    it "does not check remote host until polling interval has passed since the last observation" do
      skip "not yet implemented"
    end

    context "when to_be_destroyed is true" do

      before(:each) do
        @run.update_attribute(:to_be_destroyed, true)
      end

      it "cancels a remote job" do
        expect_any_instance_of(RemoteJobHandler).to receive(:cancel_remote_job) # do nothing
        JobObserver.__send__(:observe_host, @host, @logger)
      end

      it "destroys run" do
        allow_any_instance_of(RemoteJobHandler).to receive(:remote_status) { :includable }
        expect {
          JobObserver.__send__(:observe_host, @host, @logger)
        }.to change { Run.unscoped.count }.by(-1)
      end
    end

    context "when ssh connection error occers" do

      it "does not change run status into :failed" do
        # return "#<NoMethodError: undefined method `stat' for nil:NilClass>"
        allow_any_instance_of(RemoteJobHandler).to receive(:remote_status) { nil.stat }
        expect {
          JobObserver.__send__(:observe_host, @host, @logger)
        }.not_to change { Run.where(status: :failed).count }
      end
    end
  end
end
