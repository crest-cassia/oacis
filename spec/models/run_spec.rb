require 'spec_helper'

describe Run do

  before(:each) do
    @simulator = FactoryGirl.create(:simulator,
                                    parameter_sets_count: 1,
                                    runs_count: 1,
                                    analyzers_count: 2,
                                    run_analysis: true
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
        status: :cancelled,
        hostname: "host",
        cpu_time: 123.0,
        real_time: 456.0,
        started_at: DateTime.now,
        finished_at: DateTime.now,
        included_at: DateTime.now
      )
      run = @param_set.runs.build(@valid_attribute)
      run.status.should_not == :cancelled
      run.hostname.should be_nil
      run.cpu_time.should be_nil
      run.real_time.should be_nil
      run.started_at.should be_nil
      run.finished_at.should be_nil
      run.included_at.should be_nil
    end

    it "status must be either :created, :submitted, :running, :failed, :finished, or :cancelled" do
      run = @param_set.runs.build(@valid_attribute)
      run.status = :unknown
      run.should_not be_valid
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

    it "destroys including analyses when destroyed" do
      expect {
        @run.destroy
      }.to change { Analysis.all.count }.by(-2)
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
      sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 0)
      prm = sim.parameter_sets.first
      run = prm.runs.create!(@valid_attribute)
      FileTest.directory?(ResultDirectory.run_path(run)).should be_true
    end

    it "is not created when validation fails" do
      sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 1)
      prm = sim.parameter_sets.first
      seed_val = prm.runs.first.seed
      @valid_attribute.update(seed: seed_val)

      prev_count = Dir.entries(ResultDirectory.parameter_set_path(prm)).size
      run = prm.runs.create(@valid_attribute)
      prev_count = Dir.entries(ResultDirectory.parameter_set_path(prm)).size.should == prev_count
    end

    it "is removed when the item is destroyed" do
      sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 1)
      run = sim.parameter_sets.first.runs.first
      dir_path = run.dir
      run.destroy
      FileTest.directory?(dir_path).should be_false
    end
  end

  describe "#command_and_input" do

    context "for simulators which receives parameters as arguments" do

      it "returns a shell command to run simulation" do
        sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 1, support_input_json: false)
        prm = sim.parameter_sets.first
        run = prm.runs.first
        command, input = run.command_and_input
        command.should eq "#{sim.command} #{prm.v["L"]} #{prm.v["T"]} #{run.seed}"
        input.should be_nil
      end
    end

    context "for simulators which receives parameters as _input.json" do

      it "returns a shell command to run simulation" do
        sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 1, support_input_json: true)
        prm = sim.parameter_sets.first
        run = prm.runs.first
        command, input = run.command_and_input
        command.should eq "#{sim.command}"
        prm.v.each do |key, val|
          input[key].should eq val
        end
        input[:_seed].should eq run.seed
      end
    end
  end

  describe "#dir" do

    it "returns the result directory of the run" do
      sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 1)
      prm = sim.parameter_sets.first
      run = prm.runs.first
      run.dir.should == ResultDirectory.run_path(run)
    end
  end

  describe "#result_paths" do

    before(:each) do
      sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 1,
                               analyzers_count: 1, run_analysis: true
                               )
      prm = sim.parameter_sets.first
      @run = prm.runs.first
      @run.status = :finished
      @temp_dir = @run.dir.join('result_dir')
      FileUtils.mkdir_p(@temp_dir)
      @temp_files = [@run.dir.join('result1.txt'),
                     @run.dir.join('result2.txt'),
                     @temp_dir.join('result3.txt')]
      @temp_files.each {|f| FileUtils.touch(f) }
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
      res.should_not include(@temp_dir)
    end

    it "does not include directories of analysis" do
      entries_in_run_dir = Dir.glob(@run.dir.join('*'))
      entries_in_run_dir.size.should eq(4)
      @run.result_paths.size.should eq(3)
      arn_dir = @run.analyses.first.dir
      @run.result_paths.should_not include(arn_dir)
    end
  end

  describe "#archived_result_path" do

    before(:each) do
      sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 1)
      @run = sim.parameter_sets.first.runs.first
    end

    it "returns path to archived file" do
      @run.archived_result_path.should eq @run.dir.join("../#{@run.id}.tar.bz2")
    end

    it "is deleted when the run is destroyed" do
      FileUtils.touch( @run.archived_result_path )
      archive = @run.archived_result_path
      expect {
        @run.destroy
      }.to change { File.exist?(archive) }.from(true).to(false)
    end
  end

  describe "#enqueue_auto_run_analyzers" do

    describe "auto run of analyzers for on_run type" do

      before(:each) do
        @run = @simulator.parameter_sets.first.runs.first
        # @run.update_attributes!(status: :finished)
        @run.status = :finished
        @run.save!
        @azr = FactoryGirl.create(:analyzer, simulator: @simulator, type: :on_run, auto_run: :yes)
      end

      context "when Analyzer#auto_run is :yes" do

        it "creates analysis if status is 'finished'" do
          expect {
            @run.enqueue_auto_run_analyzers
          }.to change { @run.reload.analyses.count }.by(1)
        end

        it "do not create analysis if status is not 'finished'" do
          @run.status = :failed
          @run.save!
          expect {
            @run.enqueue_auto_run_analyzers
          }.to_not change { @run.reload.analyses.count }
        end
      end

      context "when Analyzer#auto_run is :no" do

        it "does not create analysis if Anaylzer#auto_run is :no" do
          @azr.update_attributes!(auto_run: :no)
          expect {
            @run.enqueue_auto_run_analyzers
          }.to_not change { @run.reload.analyses.count }
        end
      end

      context "when Analyzer#auto_run is :first_run_only" do

        before(:each) do
          @azr.update_attributes!(auto_run: :first_run_only)
        end

        it "creates analysis if the run is the first 'finished' run within the parameter set" do
          expect {
            @run.enqueue_auto_run_analyzers
          }.to change { @run.reload.analyses.count }.by(1)
        end

        it "does not create analysis if 'finished' run already exists within the paramter set" do
          FactoryGirl.create(:run, parameter_set: @param_set, status: :finished)
          expect {
            @run.enqueue_auto_run_analyzers
          }.to_not change { @run.reload.analyses.count }
        end
      end
    end

    describe "auto run of analyzers for on_parameter_set type" do

      before(:each) do
        @run = @simulator.parameter_sets.first.runs.first
        @run.status = :finished
        @run.save!
        @azr = FactoryGirl.create(:analyzer,
                                  simulator: @simulator, type: :on_parameter_set, auto_run: :yes)
      end

      it "creates analysis if all the other runs within the parameter set are 'finished' or 'failed'" do
        FactoryGirl.create(:run, parameter_set: @param_set, status: :failed)
        FactoryGirl.create(:run, parameter_set: @param_set, status: :finished)
        expect {
          @run.enqueue_auto_run_analyzers
        }.to change { @param_set.reload.analyses.count }.by(1)
      end

      it "does not create analysis if any of runs within the parameter set is not 'finished' or 'failed'" do
        FactoryGirl.create(:run, parameter_set: @param_set, status: :submitted)
        expect {
          @run.enqueue_auto_run_analyzers
        }.to_not change { @param_set.reload.analyses.count }
      end
    end
  end

  describe "#destroy" do

    before(:each) do
      sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 1)
      @run = sim.parameter_sets.first.runs.first
    end

    it "calls destroy if status is either :created, :failed, or :finished" do
      expect {
        @run.destroy
      }.to change { Run.count }.by(-1)
    end

    it "calls cancel if status is :submitted or :running" do
      @run.status = :submitted
      @run.should_receive(:cancel)
      @run.destroy
    end

    it "does not destroy run if status is :submitted or :running" do
      @run.status = :submitted
      run_dir = @run.dir
      archive = @run.archived_result_path
      FileUtils.touch(archive)
      expect {
        @run.destroy
      }.to_not change { Run.count }
      @run.status.should eq :cancelled
      File.exist?(run_dir).should be_false
      File.exist?(archive).should be_false
      @run.parameter_set.should be_nil
    end
  end
end
