require 'spec_helper'

describe JobSubmitter do

  describe ".perform" do

    before(:each) do
      @host = FactoryGirl.create(:localhost)
      @temp_dir = Pathname.new('__temp__')
      FileUtils.mkdir_p(@temp_dir)
      @host.work_base_dir = @temp_dir.expand_path
      @host.save!

      @logger = Logger.new(STDERR)
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
  end

  describe ".submit" do

    before(:each) do
      @sim = FactoryGirl.create(:simulator,
                                command: "echo",
                                parameter_sets_count: 1, runs_count: 1)
      @runs = @sim.parameter_sets.first.runs
      @host = @sim.executable_on.where(name: "localhost").first
      @temp_dir = Pathname.new('__temp__')
      FileUtils.mkdir_p(@temp_dir)
      @host.work_base_dir = @temp_dir.expand_path
      @host.save!
      SchedulerWrapper.any_instance.stub(:submit_command).and_return("echo")

      @logger = Logger.new(@temp_dir.join('log.txt'))
    end

    after(:each) do
      FileUtils.rm_rf(@temp_dir) if File.directory?(@temp_dir)
    end

    it "creates a work_dir on remote host" do
      JobSubmitter.__send__(:submit, @runs, @host, @logger)
      File.directory?( @temp_dir.join(@runs.first.id) ).should be_true
    end

    it "creates _input.json on remote host if simulator.support_input_json is true" do
      @sim.support_input_json = true
      @sim.save!
      JobSubmitter.__send__(:submit, @runs, @host, @logger)
      File.exist?( @temp_dir.join(@runs.first.id, '_input.json') ).should be_true
    end

    it "executes pre_process_script if simulator.pre_process_script is not empty" do
      @sim.pre_process_script = "echo hello > preprocess.txt"
      @sim.save!
      JobSubmitter.__send__(:submit, @runs, @host, @logger)
      File.exist?( @temp_dir.join(@runs.first.id, 'preprocess.txt')).should be_true
    end

    it "executes pre_process_script with arguments when support_input_json is false" do
      @sim.support_input_json = false
      @sim.pre_process_script = "echo $# > preprocess.txt"
      @sim.save!
      JobSubmitter.__send__(:submit, @runs, @host, @logger)
      File.open( @temp_dir.join(@runs.first.id, 'preprocess.txt') ).read.chomp.should eq "3"
    end

    describe "when pre_process_script fails" do

      before(:each) do
        @sim.pre_process_script = "invalid command"
        @sim.save!

        @temp_dir = Pathname.new('__temp__')
        FileUtils.mkdir_p(@temp_dir)
        @logger = Logger.new( @temp_dir.join('log.txt') )
      end

      after(:each) do
        FileUtils.rm_r(@temp_dir) if File.directory?(@temp_dir)
      end

      it "sets status of Run to failed" do
        JobSubmitter.__send__(:submit, @runs, @host, @logger)
        @runs.first.reload.status.should eq :failed
      end

      it "does not enqueue job script" do
        SchedulerWrapper.any_instance.should_not_receive(:submit_command)
        JobSubmitter.__send__(:submit, @runs, @host, @logger)
      end

      it "removes files on remote host" do
        JobSubmitter.__send__(:submit, @runs, @host, @logger)
        File.directory?( @temp_dir.join(@runs.first.id) ).should be_false
      end

      it "copies files in the remote work_dir to Run's directory" do
        JobSubmitter.__send__(:submit, @runs, @host, @logger)
        File.exist?( @runs.first.dir.join('_preprocess.sh') ).should be_true
      end
    end

    it "creates a job script on remote host" do
      JobSubmitter.__send__(:submit, @runs, @host, @logger)
      File.exist?( @temp_dir.join( @runs.first.id.to_s+'.sh') ).should be_true
    end

    it "updates status of Run" do
      JobSubmitter.__send__(:submit, @runs, @host, @logger)
      @runs.first.reload.status.should eq :submitted
    end

    it "updates submitted_at of Run" do
      expect {
        JobSubmitter.__send__(:submit, @runs, @host, @logger)
      }.to change { @runs.first.reload.submitted_at }
    end

    it "updates job_id of Run" do
      expect {
        JobSubmitter.__send__(:submit, @runs, @host, @logger)
      }.to change { @runs.first.reload.job_id }
    end

    it "calls SchedulerWrapper#submit_command" do
      SchedulerWrapper.any_instance.should_receive(:submit_command)
      JobSubmitter.__send__(:submit, @runs, @host, @logger)
    end

    it "creates ssh session only once" do
      Net::SSH.should_receive(:start).once.and_call_original
      JobSubmitter.__send__(:submit, @runs, @host, @logger)
    end
  end
end
