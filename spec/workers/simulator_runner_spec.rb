require 'spec_helper'

describe SimulatorRunner do
  
  before(:each) do
    @sim = FactoryGirl.create(:simulator,
                              parameter_sets_count: 1, runs_count: 1)
    @prm = @sim.parameter_sets.first
    @run = @prm.runs.first

    @host = FactoryGirl.create(:host)
  end

  describe ".perform" do

    before(:each) do
      @temp_dir = Pathname.new('__temp')
      FileUtils.mkdir_p(@temp_dir)
      ENV['CM_WORK_DIR'] = @temp_dir.expand_path.to_s
      @run_dir = @temp_dir.join(@run.id)
      @run_info = {"id" => @run.id, "command" => @run.command}
      Resque.stub!(:enqueue)
    end

    after(:each) do
      FileUtils.rm_r(@temp_dir) if File.directory?(@temp_dir)
    end

    it "calls Run#command method while performing simulation" do
      @run_info["command"] = "echo hello"
      SimulatorRunner.perform(@run_info)
      File.exist?(@run_dir.join('_stdout.txt')).should be_true
      File.exist?(@run_dir.join('_stderr.txt')).should be_true
      File.open(@run_dir.join('_stdout.txt')).read.should match(/hello/)
    end

    it "write status of Run to '_run_status.json' after simulation successfully finished" do
      @run_info["command"] = "sleep 1"
      SimulatorRunner.perform(@run_info)
      stat_json = @run_dir.join('_run_status.json')
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
      stat_json = @run_dir.join('_run_status.json')
      File.exist?(stat_json).should be_true

      loaded = JSON.load(File.open(stat_json))
      loaded["hostname"].should eq(`hostname`.chomp)
      DateTime.parse(loaded["started_at"]).should be_within(20/28000.0).of(DateTime.now)
      loaded["status"].should eq("failed")
      loaded["cpu_time"].should be_within(0.1).of(0.0)
      loaded["real_time"].should be_within(0.1).of(0.0)
      DateTime.parse(loaded["finished_at"]).should be_within(20/28000.0).of(DateTime.now)
    end

    it "creates working directory under CM_WORK_DIR" do
      @run_info["command"] = 'pwd'
      SimulatorRunner.perform(@run_info)

      File.directory?(@temp_dir.join(@run_info["id"])).should be_true
      @run_dir.join('_stdout.txt').read.should match(/^#{@run_dir.expand_path.to_s}$/)
    end

    it "enqueues a job for DataIncluder with hostname if 'CM_HOST_ID' is not specified" do
      ENV.delete('CM_HOST_ID')
      Resque.should_receive(:enqueue).with(DataIncluder,
                                           run_id: @run.id,
                                           work_dir: @run_dir.expand_path.to_s,
                                           hostname: `hostname`.chomp
                                           )
      SimulatorRunner.perform(@run_info)
    end

    it "enqueues a job for DataIncluder with host_id specified by 'CM_HOST_ID'" do
      ENV['CM_HOST_ID'] = @host.id
      Resque.should_receive(:enqueue).with(DataIncluder,
                                           run_id: @run.id,
                                           work_dir: @run_dir.expand_path.to_s,
                                           host_id: @host.id.to_s
                                           )
      SimulatorRunner.perform(@run_info)
    end
  end
end