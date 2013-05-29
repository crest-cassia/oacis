require 'spec_helper'

describe Run do

  before(:each) do
    @simulator = FactoryGirl.create(:simulator,
                                    parameter_sets_count: 1,
                                    runs_count: 1,
                                    parameter_set_queries_count:1
                                    )
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

    it "responds to simulator" do
      @run.should respond_to(:simulator)
      @run.simulator.should eq(@run.parameter_set.simulator)
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
      sim = FactoryGirl.create(:simulator, :parameter_sets_count => 1, :runs_count => 0, parameter_set_queries_count:1)
      prm = sim.parameter_sets.first
      run = prm.runs.create!(@valid_attribute)
      FileTest.directory?(ResultDirectory.run_path(run)).should be_true
    end

    it "is not created when validation fails" do
      sim = FactoryGirl.create(:simulator, :parameter_sets_count => 1, :runs_count => 1, parameter_set_queries_count:1)
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
      sim = FactoryGirl.create(:simulator, :parameter_sets_count => 1, :runs_count => 1, parameter_set_queries_count:1)
      prm = sim.parameter_sets.first
      run = prm.runs.first
      arg = {id: run.id, command: run.command}
      Resque.should_receive(:enqueue).with(SimulatorRunner, arg)
      run.submit
    end
  end

  describe "#command" do

    it "returns a shell command to run simulation" do
      sim = FactoryGirl.create(:simulator, :parameter_sets_count => 1, :runs_count => 1, parameter_set_queries_count:1)
      prm = sim.parameter_sets.first
      run = prm.runs.first
      run.command.should == "#{sim.command} #{prm.v["L"]} #{prm.v["T"]} #{run.seed}"
    end
  end

  describe "#dir" do

    it "returns the result directory of the run" do
      sim = FactoryGirl.create(:simulator, :parameter_sets_count => 1, :runs_count => 1, parameter_set_queries_count:1)
      prm = sim.parameter_sets.first
      run = prm.runs.first
      run.dir.should == ResultDirectory.run_path(run)
    end
  end

  describe "#result_paths" do

    before(:each) do
      sim = FactoryGirl.create(:simulator, :parameter_sets_count => 1, :runs_count => 1,
                               analyzers_count: 1, run_analysis: true, parameter_set_queries_count:1
                               )
      prm = sim.parameter_sets.first
      @run = prm.runs.first
      @run.status = :finished
      @temp_files = [@run.dir.join('result1.txt'), @run.dir.join('result2.txt')]
      @temp_files.each {|f| FileUtils.touch(f) }
      @temp_dir = @run.dir.join('result_dir')
      FileUtils.mkdir_p(@temp_dir)
    end

    after(:each) do
      @temp_files.each {|f| FileUtils.rm(f) if File.exist?(f) }
      FileUtils.rm_r(@temp_dir)
    end

    it "returns list of result files" do
      res = @run.result_paths
      @temp_files.each do |f|
        res.should include(f)
      end
      res.should include(@temp_dir)
    end

    it "does not include directories of analysis_run" do
      entries_in_run_dir = Dir.glob(@run.dir.join('*'))
      entries_in_run_dir.size.should eq(4)
      @run.result_paths.size.should eq(3)
      arn_dir = @run.analysis_runs.first.dir
      @run.result_paths.should_not include(arn_dir)
    end
  end
end
