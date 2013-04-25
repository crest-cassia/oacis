require 'spec_helper'

describe Run do

  before(:each) do
    @simulator = FactoryGirl.create(:simulator)
    @param_set = @simulator.parameter_sets.first
    @valid_attribute = {}
  end

  describe "validations" do

    it "creates a Run with a valid attribute" do
      @param_set.runs.build.should be_valid
    end

    it "assigns 'created' stauts by default" do
      run = @param_set.runs.create
      run.status.should == :created
    end

    it "assigns a seed by default" do
      run = @param_set.runs.create
      run.seed.should be_a(Integer)
    end

    it "automatically assigned seeds are unique" do
      seeds = []
      n = 10
      n.times do |i|
        run = @param_set.runs.create
        seeds << run.seed
      end
      seeds.uniq.size.should == n
    end

    it "is invalid if parameter set is not related" do
      Run.new(@valid_attribute).should_not be_valid
    end

    it "seed is an accessible attribute" do
      seed_val = 12345
      @valid_attribute.update(seed: seed_val)
      run = @param_set.runs.create!(@valid_attribute)
      run.seed.should == seed_val
    end

    it "seed must be unique" do
      seed_val = @param_set.runs.first.seed
      @valid_attribute.update(seed: seed_val)
      @param_set.runs.build(@valid_attribute).should_not be_valid
    end

    it "the attributes other than seed are not accessible" do
      @valid_attribute.update(
        status: :canceled,
        hostname: "host",
        cpu_time: 123.0,
        real_time: 456.0,
        started_at: DateTime.now,
        finished_at: DateTime.now,
        included_at: DateTime.now
      )
      run = @param_set.runs.build(@valid_attribute)
      run.status.should_not == :canceled
      run.hostname.should be_nil
      run.cpu_time.should be_nil
      run.real_time.should be_nil
      run.started_at.should be_nil
      run.finished_at.should be_nil
      run.included_at.should be_nil
    end
  end

  describe "relations" do

    before(:each) do
      @run = @param_set.runs.first
    end

    it "belongs to parameter" do
      @run.should respond_to(:parameter_set)
    end
  end

  describe "result directory" do

    before(:each) do
      @root_dir = ResultDirectory.root
      FileUtils.rm_r(@root_dir) if FileTest.directory?(@root_dir)
      FileUtils.mkdir(@root_dir)
    end

    after(:each) do
      FileUtils.rm_r(@root_dir) if FileTest.directory?(@root_dir)
    end

    it "is created when a new item is added" do
      sim = FactoryGirl.create(:simulator, :parameter_sets_count => 1, :runs_count => 0)
      prm = sim.parameter_sets.first
      run = prm.runs.create!(@valid_attribute)
      FileTest.directory?(ResultDirectory.run_path(run)).should be_true
    end

    it "is not created when validation fails" do
      sim = FactoryGirl.create(:simulator, :parameter_sets_count => 1, :runs_count => 1)
      prm = sim.parameter_sets.first
      seed_val = prm.runs.first.seed
      @valid_attribute.update(seed: seed_val)

      prev_count = Dir.entries(ResultDirectory.parameter_set_path(prm)).size
      run = prm.runs.create(@valid_attribute)
      prev_count = Dir.entries(ResultDirectory.parameter_set_path(prm)).size.should == prev_count
    end
  end

  describe "#submit" do

    it "submits a run to Resque" do
      sim = FactoryGirl.create(:simulator, :parameter_sets_count => 1, :runs_count => 1)
      prm = sim.parameter_sets.first
      run = prm.runs.first
      Resque.should_receive(:enqueue).with(SimulatorRunner, run.id)
      run.submit
    end
  end

  describe "#command" do

    it "returns a shell command to run simulation" do
      sim = FactoryGirl.create(:simulator, :parameter_sets_count => 1, :runs_count => 1)
      prm = sim.parameter_sets.first
      run = prm.runs.first
      run.command.should == "#{sim.execution_command} #{prm.v["L"]} #{prm.v["T"]} #{run.seed}"
    end
  end

  describe "#dir" do

    it "returns the result directory of the run" do
      sim = FactoryGirl.create(:simulator, :parameter_sets_count => 1, :runs_count => 1)
      prm = sim.parameter_sets.first
      run = prm.runs.first
      run.dir.should == ResultDirectory.run_path(run)
    end
  end


  describe "#set_status_running" do

    before(:each) do
      sim = FactoryGirl.create(:simulator, :parameter_sets_count => 1, :runs_count => 1)
      prm = sim.parameter_sets.first
      @run = prm.runs.first
    end

    it "updates status to 'running' and sets hostname" do
      ret = @run.set_status_running(:hostname => 'host_ABC')
      ret.should be_true

      updated_run = Run.find(@run)
      updated_run.status.should == :running
      updated_run.hostname.should == 'host_ABC'
    end
  end

  describe "#set_status_finished" do

    before(:each) do
      sim = FactoryGirl.create(:simulator, :parameter_sets_count => 1, :runs_count => 1)
      prm = sim.parameter_sets.first
      @run = prm.runs.first
      @run.set_status_running(:hostname => 'host_ABC')
    end

    it "updates status to 'finished' and sets elapsed times" do
      ret = @run.set_status_finished( {cpu_time: 1.5, real_time: 2.0} )
      ret.should be_true

      run = Run.find(@run)
      run.status.should == :finished
      run.cpu_time.should == 1.5
      run.real_time.should == 2.0
      run.finished_at.should_not be_nil
      run.included_at.should_not be_nil
    end
  end

  describe "#set_status_failed" do

    before(:each) do
      sim = FactoryGirl.create(:simulator, :parameter_sets_count => 1, :runs_count => 1)
      prm = sim.parameter_sets.first
      @run = prm.runs.first
      @run.set_status_running(:hostname => 'host_ABC')
    end

    it "updates status to 'failed'" do
      ret = @run.set_status_failed
      ret.should be_true

      run = Run.find(@run)
      run.status.should == :failed
      run.cpu_time.should be_nil
      run.real_time.should be_nil
      run.finished_at.should be_nil
    end
  end

end
