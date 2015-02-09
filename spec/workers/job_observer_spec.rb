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
      JobObserver.should_receive(:observe_host).and_return(nil)
      JobObserver.perform(@logger)
    end

    it "do nothing if host status is 'disabled'" do
      @host.update_attribute(:status, :disabled)
      JobObserver.should_not_receive(:observe_host)
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
      RemoteJobHandler.any_instance.should_receive(:remote_status).and_return(:submitted)
      JobObserver.__send__(:observe_host, @host, @logger)
      @run.reload.status.should eq :submitted
    end

    it "update status to 'running' when remote_status of Run is 'running'" do
      RemoteJobHandler.any_instance.should_receive(:remote_status).and_return(:running)
      JobObserver.__send__(:observe_host, @host, @logger)
      @run.reload.status.should eq :running
    end

    it "include remote data and update status to 'finished' or 'failed'" do
      RemoteJobHandler.any_instance.should_receive(:remote_status).and_return(:includable)
      JobIncluder.should_receive(:include_remote_job) do |host, run|
        run.id.should eq @run.id
      end
      JobObserver.__send__(:observe_host, @host, @logger)
    end

    it "does not check remote host until polling interval has passed since the last observation" do
      pending "not yet implemented"
    end

    context "when run is cancelled" do

      before(:each) do
        @run.status = :cancelled
        @run.save!
      end

      it "cancelles a remote job" do
        RemoteJobHandler.any_instance.should_receive(:cancel_remote_job) # do nothing
        JobObserver.__send__(:observe_host, @host, @logger)
      end

      it "destroys run" do
        RemoteJobHandler.any_instance.stub(:remote_status) { :includable }
        expect {
          JobObserver.__send__(:observe_host, @host, @logger)
        }.to change { Run.count }.by(-1)
      end

      it "does not include remote data even if remote status is 'includable'" do
        RemoteJobHandler.any_instance.stub(:remote_status) { :includable }
        JobIncluder.should_not_receive(:include_remote_job)
        JobObserver.__send__(:observe_host, @host, @logger)
      end
    end

    context "when ssh connection error occers" do

      it "does not change run status into :failed" do
        # return "#<NoMethodError: undefined method `stat' for nil:NilClass>"
        RemoteJobHandler.any_instance.stub(:remote_status) { nil.stat }
        expect {
          JobObserver.__send__(:observe_host, @host, @logger)
        }.not_to change { Run.where(status: :failed).count }
      end
    end
  end
end
