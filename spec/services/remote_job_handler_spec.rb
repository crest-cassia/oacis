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
        allow_any_instance_of(RemoteJobHandler).to receive(:submit_to_scheduler)
      end

      after(:each) do
        FileUtils.remove_entry_secure(@temp_dir) if File.directory?(@temp_dir)
      end

      it "creates a work_dir on remote host" do
        RemoteJobHandler.new(@host).submit_remote_job(@run)
        expect(File.directory?( @temp_dir.join(@run.id) )).to be_truthy
      end

      it "creates _input.json on remote host if simulator.support_input_json is true" do
        @sim.update_attribute(:support_input_json, true)
        RemoteJobHandler.new(@host).submit_remote_job(@run)
        expect(File.exist?( @temp_dir.join(@run.id, '_input.json') )).to be_truthy
      end

      it "executes pre_process_script if simulator.pre_process_script is not empty" do
        @sim.update_attribute(:pre_process_script, "echo hello > preprocess.txt")
        RemoteJobHandler.new(@host).submit_remote_job(@run)
        expect(File.exist?( @temp_dir.join(@run.id, 'preprocess.txt'))).to be_truthy
      end

      it "executes pre_process_script with arguments when support_input_json is false" do
        @sim.update_attribute(:support_input_json, false)
        @sim.update_attribute(:pre_process_script, "echo $# > preprocess.txt")
        RemoteJobHandler.new(@host).submit_remote_job(@run)
        expect(File.open( @temp_dir.join(@run.id, 'preprocess.txt') ).read.chomp).to eq "3"
      end

      describe "when pre_process_script fails" do

        before(:each) do
          @sim.update_attribute(:pre_process_script, "invalid command")

          @temp_dir = Pathname.new( Dir.mktmpdir )
        end

        after(:each) do
          FileUtils.rm_r(@temp_dir) if File.directory?(@temp_dir)
        end

        it "not raises any error" do
          expect {
            RemoteJobHandler.new(@host).submit_remote_job(@run)
          }.not_to raise_error
        end

        it "raises RemoteJobError" do
          expect {
            RemoteJobHandler.new(@host).submit_remote_job(@run)
          }.to change { @run.reload.error_messages }
        end

        it "raises an exception and sets status of Run to failed" do
          RemoteJobHandler.new(@host).submit_remote_job(@run) rescue nil
          expect(@run.reload.status).to eq :failed
        end

        it "does not enqueue job script" do
          expect_any_instance_of(SchedulerWrapper).not_to receive(:submit_command)
          RemoteJobHandler.new(@host).submit_remote_job(@run) rescue nil
        end

        it "removes files on remote host" do
          RemoteJobHandler.new(@host).submit_remote_job(@run) rescue nil
          expect(File.directory?( @temp_dir.join(@run.id) )).to be_falsey
        end

        it "copies files in the remote work_dir to Run's directory" do
          RemoteJobHandler.new(@host).submit_remote_job(@run) rescue nil
          expect(File.exist?( @run.dir.join('_preprocess.sh') )).to be_truthy
        end
      end

      it "creates a job script on remote host" do
        RemoteJobHandler.new(@host).submit_remote_job(@run)
        expect(File.exist?( @temp_dir.join( @run.id.to_s+'.sh') )).to be_truthy
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
        expect(@run.reload.status).to eq :submitted
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
        expect(Net::SSH).to receive(:start).once.and_call_original
        RemoteJobHandler.new(@host).submit_remote_job(@run)
      end
    end

    describe "prepare_job_script" do

      it "raise RemoteJobHandler::RemoteOperationError if rc != 0" do
        skip "not yet implemented"
      end
    end

    describe "submit_to_scheduler" do

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

      it "raise RemoteJobHandler::RemoteSchedulerError if rc != 0" do
        expect_any_instance_of(SchedulerWrapper).to receive(:submit_command).and_return("exit 1")
        expect {
          RemoteJobHandler.new(@host).submit_remote_job(@run)
        }.to raise_error(RemoteJobHandler::RemoteSchedulerError)
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
      allow(SSHUtil).to receive(:execute2).and_return(["out", "err", 0, nil])
    end

    after(:each) do
      FileUtils.rm_r(@temp_dir) if File.directory?(@temp_dir)
    end

    it "returns status parsed by SchedulerWrapper#parse_remote_status" do
      expect_any_instance_of(SchedulerWrapper).to receive(:parse_remote_status).and_return(:submitted)
      expect(RemoteJobHandler.new(@host).remote_status(@run)).to eq :submitted
    end

    it "raise RemoteSchedulerError if remote status is not obtained by SchedulerWrapper" do
      allow(SSHUtil).to receive(:execute2).and_return([nil, nil, 1, nil])
      expect {
        RemoteJobHandler.new(@host).remote_status(@run)
      }.to raise_error(RemoteJobHandler::RemoteSchedulerError)
    end

    it "run.error_message is updated if remote status is not obtained by SchedulerWrapper" do
      allow(SSHUtil).to receive(:execute2).and_return([nil, nil, 1, nil])
      expect {
        RemoteJobHandler.new(@host).remote_status(@run) rescue nil
      }.to change { @run.reload.error_messages }
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
      allow_any_instance_of(SchedulerWrapper).to receive(:cancel_command).and_return("echo")
      @handler = RemoteJobHandler.new(@host)
    end

    after(:each) do
      FileUtils.remove_entry_secure(@temp_dir) if File.directory?(@temp_dir)
    end

    context "when remote_status is :submitted" do

      before(:each) do
        allow(@handler).to receive(:remote_status).and_return(:submitted)
      end

      it "calls cancel_command of the scheduler" do
        expect_any_instance_of(SchedulerWrapper).to receive(:cancel_command)
        @handler.cancel_remote_job(@run)
      end

      it "removes_remote_file" do
        dummy_work_dir = RemoteFilePath.work_dir_path(@host, @run)
        FileUtils.mkdir_p(dummy_work_dir)
        @handler.cancel_remote_job(@run)
        expect(File.directory?(dummy_work_dir)).to be_falsey
      end
    end

    context "when remote_status is :running" do

      before(:each) do
        allow(@handler).to receive(:remote_status).and_return(:running)
      end

      it "calls cancel_command of the scheduler" do
        expect_any_instance_of(SchedulerWrapper).to receive(:cancel_command)
        @handler.cancel_remote_job(@run)
      end

      it "removes_remote_file" do
        dummy_work_dir = RemoteFilePath.work_dir_path(@host, @run)
        FileUtils.mkdir_p(dummy_work_dir)
        @handler.cancel_remote_job(@run)
        expect(File.directory?(dummy_work_dir)).to be_falsey
      end
    end

    context "when remote_status is :includable" do

      before(:each) do
        allow(@handler).to receive(:remote_status).and_return(:includable)
      end

      it "calls cancel_command of the scheduler" do
        expect_any_instance_of(SchedulerWrapper).not_to receive(:cancel_command)
        @handler.cancel_remote_job(@run)
      end

      it "removes_remote_file" do
        dummy_work_dir = RemoteFilePath.work_dir_path(@host, @run)
        FileUtils.mkdir_p(dummy_work_dir)
        @handler.cancel_remote_job(@run)
        expect(File.directory?(dummy_work_dir)).to be_falsey
      end
    end
  end

  describe "error_handle" do

    before(:each) do
      @sim = FactoryGirl.create(:simulator,
                                command: "echo",
                                parameter_sets_count: 1, runs_count: 1)
      @run = @sim.parameter_sets.first.runs.first
      @host = @sim.executable_on.where(name: "localhost").first
      @host.save!
    end

    context "when it get RemoteJobHandler::RemoteOperationError" do

      it "write error_message" do
        expect_any_instance_of(RemoteJobHandler).to receive(:create_remote_work_dir).and_raise(RemoteJobHandler::RemoteOperationError, "error")
        expect {
          RemoteJobHandler.new(@host).submit_remote_job(@run) rescue nil
        }.to change { @run.reload.error_messages }
      end

      it "does not change run status" do
        expect_any_instance_of(RemoteJobHandler).to receive(:create_remote_work_dir).and_raise(RemoteJobHandler::RemoteOperationError, "error")
        expect {
          RemoteJobHandler.new(@host).submit_remote_job(@run) rescue nil
        }.not_to change { @run.reload.status }
      end
    end
    context "when it get RemoteJobHandler::RemoteJobError" do

      it "write error_message" do
        expect_any_instance_of(RemoteJobHandler).to receive(:create_remote_work_dir).and_raise(RemoteJobHandler::RemoteJobError, "error")
        expect {
          RemoteJobHandler.new(@host).submit_remote_job(@run) rescue nil
        }.to change { @run.reload.error_messages }
      end

      it "changes run status to :failed" do
        expect_any_instance_of(RemoteJobHandler).to receive(:create_remote_work_dir).and_raise(RemoteJobHandler::RemoteJobError)
        expect {
          RemoteJobHandler.new(@host).submit_remote_job(@run) rescue nil
        }.to change { @run.reload.status }.to(:failed)
      end
    end
    context "when it get RemoteJobHandler::RemoteSchedulerError" do

      it "write error_message" do
        expect_any_instance_of(RemoteJobHandler).to receive(:create_remote_work_dir).and_raise(RemoteJobHandler::RemoteSchedulerError, "error")
        expect {
          RemoteJobHandler.new(@host).submit_remote_job(@run) rescue nil
        }.to change { @run.reload.error_messages }
      end

      it "changes run status to :failed" do
        expect_any_instance_of(RemoteJobHandler).to receive(:create_remote_work_dir).and_raise(RemoteJobHandler::RemoteSchedulerError, "error")
        expect {
          RemoteJobHandler.new(@host).submit_remote_job(@run) rescue nil
        }.to change { @run.reload.status }.to(:failed)
      end
    end

    context "when it get ssh connection error" do

      it "write error_message" do
        expect_any_instance_of(RemoteJobHandler).to receive(:create_remote_work_dir).and_raise("#<NoMethodError: undefined method `stat' for nil:NilClass>")
        expect {
          RemoteJobHandler.new(@host).submit_remote_job(@run) rescue nil
        }.to change { @run.reload.error_messages }.to match(/failed to establish ssh connection to host\(#{@run.submitted_to.name}\)/)
      end

      it "does not change run status" do
        expect_any_instance_of(RemoteJobHandler).to receive(:create_remote_work_dir).and_raise("#<NoMethodError: undefined method `stat' for nil:NilClass>")
        expect {
          RemoteJobHandler.new(@host).submit_remote_job(@run) rescue nil
        }.not_to change { @run.reload.status }
      end
    end

    context "when it get unknown error" do

      it "write error_message" do
        expect_any_instance_of(RemoteJobHandler).to receive(:create_remote_work_dir).and_raise("test error")
        expect {
          RemoteJobHandler.new(@host).submit_remote_job(@run) rescue nil
        }.to change { @run.reload.error_messages }.to match(/#<RuntimeError: test error>\n/)
      end
    end
  end
end
