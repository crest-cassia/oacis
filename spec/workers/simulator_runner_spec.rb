require 'spec_helper'

describe SimulatorRunner do
  
  before(:each) do
    @sim = FactoryGirl.create(:simulator,
                              parameter_sets_count: 1, runs_count: 1, parameter_set_queries_count:1)
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
      command, input = @run.command_and_input
      @run_info = {"id" => @run.id, "command" => command, "input" => input}
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

    it "does not create _input.json when 'input' arg is not given" do
      @run_info.delete("input")
      SimulatorRunner.perform(@run_info)
      File.exist?(@run_dir.join('_input.json')).should be_false
    end

    it "creates _input.json when 'input' arg is given" do
      @run_info["input"] = {'a' => 1234}
      SimulatorRunner.perform(@run_info)
      File.exist?(@run_dir.join('_input.json')).should be_true
    end

    it "sends status of Run as an argument of Resque::enqueue after simulation successfully finished" do
      @run_info["command"] = "sleep 1"

      Resque.should_receive(:enqueue).once.ordered do |klass, arg|
        klass.should eq DataIncluder
        arg[:run_id].should eq @run.id
        arg[:work_dir].should be_nil
        arg[:run_status][:hostname].should_not be_nil
        arg[:run_status][:started_at].should_not be_nil
        arg[:run_status][:status].should eq :running
        arg[:run_status][:cpu_time].should be_nil
        arg[:run_status][:real_time].should be_nil
        arg[:run_status][:finished_at].should be_nil
      end
      Resque.should_receive(:enqueue).once.ordered do |klass, arg|
        klass.should eq DataIncluder
        arg[:run_id].should eq @run.id
        arg[:work_dir].should eq @run_dir.expand_path.to_s
        arg[:run_status][:hostname].should eq `hostname`.chomp
        arg[:run_status][:started_at].should be_within(20/28000.0).of(DateTime.now)
        arg[:run_status][:status].should eq :finished
        arg[:run_status][:cpu_time].should be_within(0.1).of(0.0)
        arg[:run_status][:real_time].should be_within(0.1).of(1.0)
        arg[:run_status][:finished_at].should be_within(20/28000.0).of(DateTime.now)
      end

      SimulatorRunner.perform(@run_info)
    end

    it "sets status 'failed' if the return code of the command is not zero" do
      @run_info["command"] = "INVALID_CMD"

      Resque.should_receive(:enqueue).once.ordered do |klass, arg|
        klass.should eq DataIncluder
        arg[:run_id].should eq @run.id
        arg[:work_dir].should be_nil
        arg[:run_status][:hostname].should_not be_nil
        arg[:run_status][:started_at].should_not be_nil
        arg[:run_status][:status].should eq :running
        arg[:run_status][:cpu_time].should be_nil
        arg[:run_status][:real_time].should be_nil
        arg[:run_status][:finished_at].should be_nil
      end
      Resque.should_receive(:enqueue).once.ordered do |klass, arg|
        klass.should eq DataIncluder
        arg[:run_id].should eq @run.id
        arg[:work_dir].should eq @run_dir.expand_path.to_s
        arg[:run_status][:hostname].should eq `hostname`.chomp
        arg[:run_status][:started_at].should be_within(20/28000.0).of(DateTime.now)
        arg[:run_status][:status].should eq :failed
        arg[:run_status][:cpu_time].should be_within(0.1).of(0.0)
        arg[:run_status][:real_time].should be_within(0.1).of(0.0)
        arg[:run_status][:finished_at].should be_within(20/28000.0).of(DateTime.now)
      end

      SimulatorRunner.perform(@run_info)
    end

    it "creates working directory under CM_WORK_DIR" do
      @run_info["command"] = 'pwd'
      SimulatorRunner.perform(@run_info)

      File.directory?(@temp_dir.join(@run_info["id"])).should be_true
      @run_dir.join('_stdout.txt').read.should match(/^#{@run_dir.expand_path.to_s}$/)
    end

    it "enqueues a job for DataIncluder with hostname if 'CM_HOST_ID' is not specified" do
      ENV.delete('CM_HOST_ID')
      Resque.should_receive(:enqueue).once.ordered
      Resque.should_receive(:enqueue) do |klass, arg|
        klass.should eq DataIncluder
        arg[:host_id].should be_nil
      end
      SimulatorRunner.perform(@run_info)
    end

    it "enqueues a job for DataIncluder with host_id specified by 'CM_HOST_ID'" do
      ENV['CM_HOST_ID'] = @host.id
      Resque.should_receive(:enqueue).once.ordered
      Resque.should_receive(:enqueue).once.ordered do |klass, arg|
        klass.should eq DataIncluder
        arg[:host_id].should_not be_nil
      end
      SimulatorRunner.perform(@run_info)
    end
  end
end