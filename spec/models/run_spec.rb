require 'spec_helper'

describe Run do

  before(:each) do
    @simulator = FactoryGirl.create(:simulator)
    @parameter = @simulator.parameters.first
    @valid_attribute = {}
  end

  describe "validations" do

    it "creates a Run with a valid attribute" do
      @parameter.runs.build.should be_valid
    end

    it "assigns 'created' stauts by default" do
      run = @parameter.runs.create
      run.status.should == :created
    end

    it "assigns a seed by default" do
      run = @parameter.runs.create
      run.seed.should be_a(Integer)
    end

    it "automatically assigned seeds are unique" do
      seeds = []
      n = 10
      n.times do |i|
        run = @parameter.runs.create
        seeds << run.seed
      end
      seeds.uniq.size.should == n
    end

    it "is invalid if parameter is not related" do
      Run.new(@valid_attribute).should_not be_valid
    end

    it "seed is an accessible attribute" do
      seed_val = 12345
      @valid_attribute.update(seed: seed_val)
      run = @parameter.runs.create!(@valid_attribute)
      run.seed.should == seed_val
    end

    it "seed must be unique" do
      seed_val = @parameter.runs.first.seed
      @valid_attribute.update(seed: seed_val)
      @parameter.runs.build(@valid_attribute).should_not be_valid
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
      run = @parameter.runs.build(@valid_attribute)
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
      @run = @parameter.runs.first
    end

    it "belongs to parameter" do
      @run.should respond_to(:parameter)
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
      sim = FactoryGirl.create(:simulator, :parameters_count => 1, :runs_count => 0)
      prm = sim.parameters.first
      run = prm.runs.create!(@valid_attribute)
      FileTest.directory?(ResultDirectory.run_path(run)).should be_true
    end

    it "is not created when validation fails" do
      sim = FactoryGirl.create(:simulator, :parameters_count => 1, :runs_count => 1)
      prm = sim.parameters.first
      seed_val = prm.runs.first.seed
      @valid_attribute.update(seed: seed_val)

      prev_count = Dir.entries(ResultDirectory.parameter_path(prm)).size
      run = prm.runs.create(@valid_attribute)
      prev_count = Dir.entries(ResultDirectory.parameter_path(prm)).size.should == prev_count
    end
  end

  describe "#submit" do

    it "submits a run to Resque" do
      sim = FactoryGirl.create(:simulator, :parameters_count => 1, :runs_count => 1)
      prm = sim.parameters.first
      run = prm.runs.first
      Resque.should_receive(:enqueue).with(SimulatorRunner, run.id)
      run.submit
    end
  end

  describe "#command" do

    it "returns a shell command to run simulation" do
      sim = FactoryGirl.create(:simulator, :parameters_count => 1, :runs_count => 1)
      prm = sim.parameters.first
      run = prm.runs.first
      run.command.should == "#{sim.execution_command} #{prm.sim_parameters["L"]} #{prm.sim_parameters["T"]} #{run.seed}"
    end
  end

end
