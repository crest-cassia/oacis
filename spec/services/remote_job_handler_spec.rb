require 'spec_helper'

describe RemoteJobHandler do

  describe ".submit_remote_job" do

    describe "prepare job" do

      before(:each) do
        @sim = FactoryGirl.create(:simulator,
                                  command: "echo",
                                  parameter_sets_count: 1, runs_count: 1)
        @run = @sim.parameter_sets.first.runs.first
        @host = @sim.executable_on.where(name: "localhost").first
        @temp_dir = Pathname.new( Dir.mktmpdir )
        @host.work_base_dir = @temp_dir.expand_path
        @host.save!
        RemoteJobHandler.any_instance.stub(:submit_to_scheduler)
      end

      after(:each) do
        FileUtils.remove_entry_secure(@temp_dir) if File.directory?(@temp_dir)
      end

      it "creates a work_dir on remote host" do
        RemoteJobHandler.new(@host).submit_remote_job(@run)
        File.directory?( @temp_dir.join(@run.id) ).should be_truthy
      end

      it "creates _input.json on remote host if simulator.support_input_json is true" do
        @sim.update_attribute(:support_input_json, true)
        RemoteJobHandler.new(@host).submit_remote_job(@run)
        File.exist?( @temp_dir.join(@run.id, '_input.json') ).should be_truthy
      end

      it "executes pre_process_script if simulator.pre_process_script is not empty" do
        @sim.update_attribute(:pre_process_script, "echo hello > preprocess.txt")
        RemoteJobHandler.new(@host).submit_remote_job(@run)
        File.exist?( @temp_dir.join(@run.id, 'preprocess.txt')).should be_truthy
      end

      it "executes pre_process_script with arguments when support_input_json is false" do
        @sim.update_attribute(:support_input_json, false)
        @sim.update_attribute(:pre_process_script, "echo $# > preprocess.txt")
        RemoteJobHandler.new(@host).submit_remote_job(@run)
        File.open( @temp_dir.join(@run.id, 'preprocess.txt') ).read.chomp.should eq "3"
      end

      describe "when pre_process_script fails" do

        before(:each) do
          @sim.update_attribute(:pre_process_script, "invalid command")

          @temp_dir = Pathname.new( Dir.mktmpdir )
        end

        after(:each) do
          FileUtils.rm_r(@temp_dir) if File.directory?(@temp_dir)
        end

        def call_submit_remote_job
          begin
            RemoteJobHandler.new(@host).submit_remote_job(@run)
          rescue RemoteJobHandler::RemoteOperationError
            nil
          end
        end

        it "raises RemoteOperationError" do
          expect {
            RemoteJobHandler.new(@host).submit_remote_job(@run)
          }.to raise_error(RemoteJobHandler::RemoteOperationError)
        end

        it "raises an exception and sets status of Run to failed" do
          call_submit_remote_job
          @run.reload.status.should eq :failed
        end

        it "does not enqueue job script" do
          SchedulerWrapper.any_instance.should_not_receive(:submit_command)
          call_submit_remote_job
        end

        it "removes files on remote host" do
          call_submit_remote_job
          File.directory?( @temp_dir.join(@run.id) ).should be_falsey
        end

        it "copies files in the remote work_dir to Run's directory" do
          call_submit_remote_job
          File.exist?( @run.dir.join('_preprocess.sh') ).should be_truthy
        end
      end

      it "creates a job script on remote host" do
        RemoteJobHandler.new(@host).submit_remote_job(@run)
        File.exist?( @temp_dir.join( @run.id.to_s+'.sh') ).should be_truthy
      end
    end

    describe "submit_to_xsub" do

      before(:each) do
        @sim = FactoryGirl.create(:simulator,
                                  command: "echo",
                                  parameter_sets_count: 1, runs_count: 1)
        @run = @sim.parameter_sets.first.runs.first
        @host = @sim.executable_on.where(name: "localhost").first
        @temp_dir = Pathname.new( Dir.mktmpdir )
        @host.work_base_dir = @temp_dir.expand_path
        @host.save!
      end

      after(:each) do
        begin
         FileUtils.remove_entry_secure(@temp_dir) if File.directory?(@temp_dir)
        rescue
          sleep 1
          retry
        end
      end

      it "updates status of Run to :submitted" do
        RemoteJobHandler.new(@host).submit_remote_job(@run)
        @run.reload.status.should eq :submitted
      end

      it "updates submitted_at of Run" do
        expect {
          RemoteJobHandler.new(@host).submit_remote_job(@run)
        }.to change { @run.reload.submitted_at }
      end

      it "updates job_id of Run" do
        expect {
          RemoteJobHandler.new(@host).submit_remote_job(@run)
        }.to change { @run.reload.job_id }
      end

      it "creates ssh session only once" do
        Net::SSH.should_receive(:start).once.and_call_original
        RemoteJobHandler.new(@host).submit_remote_job(@run)
      end
    end
  end

  describe ".remote_status" do

    before(:each) do
      @sim = FactoryGirl.create(:simulator,
                                parameter_sets_count: 1, runs_count: 1)
      @run = @sim.parameter_sets.first.runs.first
      @run.job_id = "12345"
      @host = @sim.executable_on.where(name: "localhost").first
      @temp_dir = Pathname.new('__temp__')
      FileUtils.mkdir_p(@temp_dir)
      @host.work_base_dir = @temp_dir.expand_path
      @host.save!
      SSHUtil.stub(:execute2).and_return(["out", "err", 0, nil])
    end

    after(:each) do
      FileUtils.rm_r(@temp_dir) if File.directory?(@temp_dir)
    end

    it "returns status parsed by SchedulerWrapper#parse_remote_status" do
      SchedulerWrapper.any_instance.should_receive(:parse_remote_status).and_return(:submitted)
      RemoteJobHandler.new(@host).remote_status(@run).should eq :submitted
    end

    it "returns :unknown if remote status is not obtained by SchedulerWrapper" do
      SSHUtil.stub(:execute2).and_return([nil, nil, 1, nil])
      RemoteJobHandler.new(@host).remote_status(@run).should eq :unknown
    end
  end

  describe ".cancel_remote_job" do

    before(:each) do
      @sim = FactoryGirl.create(:simulator,
                                command: "echo",
                                parameter_sets_count: 1, runs_count: 1)
      @run = @sim.parameter_sets.first.runs.first
      @host = @sim.executable_on.where(name: "localhost").first
      @temp_dir = Pathname.new( Dir.mktmpdir )
      @host.update_attribute(:work_base_dir, @temp_dir.expand_path)
      SchedulerWrapper.any_instance.stub(:cancel_command).and_return("echo")
      @handler = RemoteJobHandler.new(@host)
    end

    after(:each) do
      FileUtils.remove_entry_secure(@temp_dir) if File.directory?(@temp_dir)
    end

    context "when remote_status is :submitted" do

      before(:each) do
        @handler.stub(:remote_status).and_return(:submitted)
      end

      it "calls cancel_command of the scheduler" do
        SchedulerWrapper.any_instance.should_receive(:cancel_command)
        @handler.cancel_remote_job(@run)
      end

      it "removes_remote_file" do
        dummy_work_dir = RemoteFilePath.work_dir_path(@host, @run)
        FileUtils.mkdir_p(dummy_work_dir)
        @handler.cancel_remote_job(@run)
        File.directory?(dummy_work_dir).should be_falsey
      end
    end

    context "when remote_status is :running" do

      before(:each) do
        @handler.stub(:remote_status).and_return(:running)
      end

      it "calls cancel_command of the scheduler" do
        SchedulerWrapper.any_instance.should_receive(:cancel_command)
        @handler.cancel_remote_job(@run)
      end

      it "removes_remote_file" do
        dummy_work_dir = RemoteFilePath.work_dir_path(@host, @run)
        FileUtils.mkdir_p(dummy_work_dir)
        @handler.cancel_remote_job(@run)
        File.directory?(dummy_work_dir).should be_falsey
      end
    end

    context "when remote_status is :includable" do

      before(:each) do
        @handler.stub(:remote_status).and_return(:includable)
      end

      it "calls cancel_command of the scheduler" do
        SchedulerWrapper.any_instance.should_not_receive(:cancel_command)
        @handler.cancel_remote_job(@run)
      end

      it "removes_remote_file" do
        dummy_work_dir = RemoteFilePath.work_dir_path(@host, @run)
        FileUtils.mkdir_p(dummy_work_dir)
        @handler.cancel_remote_job(@run)
        File.directory?(dummy_work_dir).should be_falsey
      end
    end
  end
end
