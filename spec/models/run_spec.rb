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
    @valid_attribute = {
      submitted_to: Host.first
    }
  end

  describe "default_scope" do

    it "ignores Run of to_be_destroyed=true by default" do
      run = Run.first
      expect {
        run.update_attribute(:to_be_destroyed, true)
      }.to change { Run.count }.by(-1)
      expect( Run.all.to_a ).to_not include(run)
    end
  end

  describe "validations" do

    it "creates a Run with a valid attribute" do
      expect(@param_set.runs.build(@valid_attribute)).to be_valid
    end

    it "assigns 'created' stauts by default" do
      run = @param_set.runs.create
      expect(run.status).to eq(:created)
    end

    it "status must be either :created, :submitted, :running, :failed, or :finished" do
      run = @param_set.runs.build(@valid_attribute)
      run.status = :unknown
      expect(run).not_to be_valid
    end

    it "mpi_procs must be present" do
      run = @param_set.runs.build(@valid_attribute)
      run.mpi_procs = nil
      expect(run).not_to be_valid
    end

    it "omp_threads must be present" do
      run = @param_set.runs.build(@valid_attribute)
      run.omp_threads = nil
      expect(run).not_to be_valid
    end

    it "mpi_procs must between Host#min_mpi_procs and Host#max_mpi_procs" do
      run = @param_set.runs.build(@valid_attribute)
      host = run.submitted_to
      host.update_attributes(min_mpi_procs: 1, max_mpi_procs: 256)
      run.mpi_procs = 256
      expect(run).to be_valid
      run.mpi_procs = 512
      expect(run).not_to be_valid
    end

    it "skips validation of mpi_procs for a persisted document" do
      run = @param_set.runs.build(@valid_attribute)
      host = run.submitted_to
      host.update_attributes(min_mpi_procs: 1, max_mpi_procs: 256)
      run.mpi_procs = 256
      run.save!
      host.update_attribute(:max_mpi_procs, 128)
      expect(run).to be_valid
    end

    it "omp_threads must between Host#min_omp_threads and Host#max_omp_threads" do
      run = @param_set.runs.build(@valid_attribute)
      host = run.submitted_to
      host.update_attributes(min_omp_threads: 1, max_omp_threads: 256)
      run.omp_threads = 256
      expect(run).to be_valid
      run.omp_threads = 512
      expect(run).not_to be_valid
    end

    it "skips validation of omp_threads for a persisted document" do
      run = @param_set.runs.build(@valid_attribute)
      host = run.submitted_to
      host.update_attributes(min_omp_threads: 1, max_omp_threads: 256)
      run.omp_threads = 256
      run.save!
      host.update_attribute(:max_omp_threads, 128)
      expect(run).to be_valid
    end

    it "assigns a priority by default" do
      run = @param_set.runs.create
      expect(run.priority).to be_a(Integer)
    end

    it "automatically assigned priority is 1" do
      run = @param_set.runs.create
      expect(run.priority).to eq 1
    end

    describe "seed" do
      it "assigns a seed by default" do
        run = @param_set.runs.create
        expect(run.seed).to be_a(Integer)
      end

      it "automatically assigned seeds are unique" do
        seeds = []
        n = 10
        n.times do |i|
          run = @param_set.runs.create
          seeds << run.seed
        end
        expect(seeds.uniq.size).to eq(n)
      end

      it "seeds must be less than 2**31-1" do
        run = @param_set.runs.create
        expect( run.seed ).to be < 2**31
      end

      context "when Simulator#sequential_seed is true" do

        before(:each) do
          @simulator.update_attribute(:sequential_seed, true)
          @param_set.runs.destroy
        end

        it "creates seed in sequential order starting from one" do
          3.times do |i|
            run = @param_set.runs.create
            expect(run.seed).to eq i+1
          end
        end

        it "does not override when seed is explicitly specified" do
          run = @param_set.runs.create(seed: 2)
          expect( run.seed ).to eq 2
          seeds = []
          3.times do |i|
            r = @param_set.runs.create
            seeds << r.seed
          end
          expect( seeds ).to eq [1,3,4]
        end
      end
    end

    describe "'host_parameters' field" do

      before(:each) do
        hpds = [ HostParameterDefinition.new(key: "node", default: "x", format: '\w+') ]
        @host = FactoryGirl.create(:host, host_parameter_definitions: hpds)
      end

      it "is valid when host_parameters are properly given" do
        run = @param_set.runs.build(@valid_attribute)
        run.submitted_to = @host
        run.mpi_procs = 8
        run.host_parameters = {"node" => "abc"}
        expect(run).to be_valid
      end

      it "is valid when key of the host parameters are symbols" do
        run = @param_set.runs.build(@valid_attribute)
        run.submitted_to = @host
        run.mpi_procs = 8
        run.host_parameters = {node: "abc"}
        expect(run).to be_valid
      end

      it "is invalid when all the host_parameters are not specified" do
        run = @param_set.runs.build(@valid_attribute)
        run.submitted_to = @host
        run.mpi_procs = 8
        run.host_parameters = {}
        expect(run).not_to be_valid
      end

      it "is valid when host_parameters have redundant keys" do
        run = @param_set.runs.build(@valid_attribute)
        run.submitted_to = @host
        run.mpi_procs = 8
        run.omp_threads = 8
        run.host_parameters = {"node" => "abd", "shape" => "xyz"}
        expect(run).to be_valid
        run.save
        expect(run.host_parameters).to_not include("shape")
      end

      it "is invalid when host_parameters does not match the defined format" do
        run = @param_set.runs.build(@valid_attribute)
        run.submitted_to = @host
        run.host_parameters = {"node" => "!!!"}
        expect(run).not_to be_valid
      end

      it "skips validation for a persisted run" do
        run = @param_set.runs.build(@valid_attribute)
        run.submitted_to = @host
        run.mpi_procs = 8
        run.host_parameters = {"node" => "abc"}
        run.save!
        @host.update_attribute(:host_parameter_definitions, @host.host_parameter_definitions + [HostParameterDefinition.new(key: "param1", default: "aaa", format: '\w+')])
        expect(run).to be_valid
      end
    end

    it "submitted_to can be nil" do
      run = @param_set.runs.build(@valid_attribute.update({submitted_to: nil}))
      expect(run).to be_valid
    end
  end

  describe "relations" do

    before(:each) do
      @run = @param_set.runs.first
    end

    it "belongs to parameter" do
      expect(@run).to respond_to(:parameter_set)
    end

    it "responds to simulator" do
      expect(@run).to respond_to(:simulator)
      expect(@run.simulator).to eq(@run.parameter_set.simulator)
    end

    it "returns simulator even when run is not saved" do
      run = @param_set.runs.build
      expect(run.simulator).to be_a(Simulator)
    end

    it "does not destroy including analyses" do
      expect {
        @run.destroy
      }.to_not change { Analysis.all.count }
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
      expect(FileTest.directory?(ResultDirectory.run_path(run))).to be_truthy
    end

    it "is not created when validation fails" do
      sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 1)
      prm = sim.parameter_sets.first
      @valid_attribute.update(status: nil)

      expect {
        prm.runs.create(@valid_attribute)
      }.not_to change {Dir.entries(ResultDirectory.parameter_set_path(prm)).size }
    end

    it "is removed when the item is destroyed" do
      sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 1)
      run = sim.parameter_sets.first.runs.first
      dir_path = run.dir
      run.destroy
      expect(FileTest.directory?(dir_path)).to be_falsey
    end
  end

  describe "#command_with_args" do

    context "for simulators which receives parameters as arguments" do

      it "returns a shell command to run simulation" do
        sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 1, support_input_json: false)
        prm = sim.parameter_sets.first
        run = prm.runs.first
        command = run.command_with_args
        expect(command).to eq "#{sim.command} #{prm.v["L"]} #{prm.v["T"]} #{run.seed}"
        expect(run.input).to be_nil
      end
    end

    context "for simulators which receives parameters as _input.json" do

      it "returns a shell command to run simulation" do
        sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 1, support_input_json: true)
        prm = sim.parameter_sets.first
        run = prm.runs.first
        command = run.command_with_args
        expect(command).to eq "#{sim.command}"
        input = run.input
        prm.v.each do |key, val|
          expect(input[key]).to eq val
        end
        expect(input[:_seed]).to eq run.seed
      end
    end
  end

  describe "#dir" do

    it "returns the result directory of the run" do
      sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 1)
      prm = sim.parameter_sets.first
      run = prm.runs.first
      expect(run.dir).to eq(ResultDirectory.run_path(run))
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
      @temp_files[0..1].each do |f|
        expect(res).to include(f)
      end
      expect(res).to include(@temp_dir)
      expect(res).not_to include(@temp_files[2])
    end

    it "does not include directories of analysis" do
      entries_in_run_dir = Dir.glob(@run.dir.join('*'))
      expect(entries_in_run_dir.size).to eq(4)
      expect(@run.result_paths.size).to eq(3)
      anl_dir = @run.analyses.first.dir
      expect(@run.result_paths).not_to include(anl_dir)
    end

    context "when pattern is given" do

      it "returns matched files" do
        pattern = "result1.txt\0result_dir/result3.txt"
        paths = @run.result_paths(pattern)
        expected = %w(result1.txt result_dir/result3.txt).map {|f| @run.dir.join(f) }
        expect(paths).to match_array expected
      end

      it "does not include analysis directories even if it matches the pattern" do
        pattern = "*"
        paths = @run.result_paths(pattern)
        expected = %w(result1.txt result2.txt result_dir).map {|f| @run.dir.join(f) }
        expect(paths).to match_array expected
      end
    end
  end

  describe "#archived_result_path" do

    before(:each) do
      sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 1)
      @run = sim.parameter_sets.first.runs.first
    end

    it "returns path to archived file" do
      expect(@run.archived_result_path).to eq @run.dir.join("../#{@run.id}.tar.bz2")
    end

    it "is deleted when the run is destroyed" do
      FileUtils.touch( @run.archived_result_path )
      archive = @run.archived_result_path
      expect {
        @run.destroy
      }.to change { File.exist?(archive) }.from(true).to(false)
    end
  end


  describe "#destroy" do

    before(:each) do
      sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 1)
      @run = sim.parameter_sets.first.runs.first
    end

    it "deletes the document" do
      expect {
        @run.destroy
      }.to change { Run.count }.by(-1)
    end

    it "deletes job script and _input.json created for manual submission" do
      sim = @run.simulator
      sim.update_attribute(:support_input_json, true)
      run = sim.parameter_sets.first.runs.create(submitted_to: nil)
      sh_path = ResultDirectory.manual_submission_job_script_path(run)
      json_path = ResultDirectory.manual_submission_input_json_path(run)

      expect(sh_path).to be_exist
      expect(json_path).to be_exist
      run.destroy
      expect(sh_path).not_to be_exist
      expect(json_path).not_to be_exist
    end

    it "deletes preprocess script and preprocess executor created for manual submission" do
      sim = @run.simulator
      sim.update_attribute(:pre_process_script, 'echo "Hello" > preprocess_result.txt')
      run = sim.parameter_sets.first.runs.create(submitted_to: nil)
      pre_process_script_path = ResultDirectory.manual_submission_pre_process_script_path(run)
      pre_process_executor_path = ResultDirectory.manual_submission_pre_process_executor_path(run)

      expect(pre_process_script_path).to be_exist
      expect(pre_process_executor_path).to be_exist
      run.destroy
      expect(pre_process_script_path).not_to be_exist
      expect(pre_process_executor_path).not_to be_exist
    end
  end

  describe "#discard" do

    before(:each) do
      sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 1)
      @run = sim.parameter_sets.first.runs.first
    end

    it "updates 'to_be_destroyed' to true" do
      expect {
        @run.discard
      }.to change { @run.to_be_destroyed }.from(false).to(true)
    end

    it "should receive 'set_lower_submittable_to_be_destroyed'" do
      expect(@run).to receive(:set_lower_submittable_to_be_destroyed)
      @run.discard
    end
  end

  describe "#set_lower_submittable_to_be_destroyed" do

    before(:each) do
      @sim = FactoryGirl.create(:simulator,
                                parameter_sets_count: 1,
                                runs_count: 1,
                                analyzers_count: 2,
                                run_analysis: true
                                )
    end

    it "sets to_be_destroyed of analyses" do
      run = @sim.runs.first
      expect {
        run.set_lower_submittable_to_be_destroyed
      }.to change { run.analyses.all.all?(&:to_be_destroyed?) }.from(false).to(true)
    end

    it "makes analyses empty" do
      run = @sim.runs.first
      expect {
        run.set_lower_submittable_to_be_destroyed
      }.to change { run.analyses.empty? }.from(false).to(true)
    end

    it "does not destroy analyses" do
      run = @sim.runs.first
      expect {
        run.set_lower_submittable_to_be_destroyed
      }.to_not change { run.analyses.unscoped.count }
    end
  end

  describe "#destroyable?" do

    before(:each) do
      @sim = FactoryGirl.create(:simulator,
                                parameter_sets_count: 1,
                                runs_count: 1,
                                analyzers_count: 2,
                                run_analysis: true
                                )
    end

    it "returns false when analyses exists" do
      run = @sim.runs.first
      run.set_lower_submittable_to_be_destroyed
      expect( run.destroyable? ).to be_falsey
    end

    it "returns true when analyses does not exist" do
      run = @sim.runs.first
      run.analyses.unscoped.destroy
      expect( run.destroyable? ).to be_truthy
    end
  end

  describe "after_create callbacks" do

    it "sets job script" do
      run = @param_set.runs.build(submitted_to: Host.first)
      expect(run.job_script).not_to be_present
      run.save!
      expect(run.job_script).to be_present
    end

    it "sets job script after seed is set" do
      @param_set.simulator.update_attribute(:support_input_json, false)
      run = @param_set.runs.create(submitted_to: Host.first)
      pattern = /#{run.command_with_args}; }/
      expect( run.job_script ).to match pattern
      # if job script was made before seed is set,
      # the job script will generate a command without seed
    end

    it "sets keys of host_parameters to string even if given as a symbol" do
      host = FactoryGirl.create(:host_with_parameters)
      param = {param1: 3, param2: 1}
      expected = {"param1" => 3, "param2" => 1}
      run = @param_set.runs.build(submitted_to: host, host_parameters: param)
      expect {
        run.save!
      }.to change { run.host_parameters }.from(param).to(expected)
    end

    it "sets default_host_parameters to simulator" do
      host = FactoryGirl.create(:host_with_parameters)
      param = {"param1" => 3, "param2" => 1}
      run = @param_set.runs.build(submitted_to: host, host_parameters: param)
      expect {
        run.save!
      }.to change { run.simulator.default_host_parameters[host.id.to_s] }.from(nil).to(param)
    end

    it "sets default_mpi values" do
      @simulator.update_attribute(:support_mpi, true)
      h = Host.first
      run = @param_set.runs.build(submitted_to: h, mpi_procs: 2)
      expect {
        run.save!
      }.to change { run.simulator.reload.default_mpi_procs[h.id.to_s] }.to(2)
    end

    it "sets default_omp values" do
      @simulator.update_attribute(:support_omp, true)
      h = Host.first
      run = @param_set.runs.build(submitted_to: h, omp_threads: 4)
      expect {
        run.save!
      }.to change { run.simulator.default_omp_threads[h.id.to_s] }.to(4)
    end

    context "when submitted_to is nil" do

      it "creates a job-script" do
        run = @param_set.runs.create!(submitted_to: nil)
        expect(ResultDirectory.manual_submission_job_script_path(run)).to be_exist
      end

      it "create _input.json" do
        @simulator.update_attribute(:support_input_json, true)
        run = @param_set.runs.create!(submitted_to: nil)
        expect(ResultDirectory.manual_submission_input_json_path(run)).to be_exist
      end

      context "when simulator.pre_process exists" do

        it "creates a preprocess script" do
          @simulator.update_attribute(:pre_process_script, 'echo "Hello" > preprocess_result.txt')
          run = @param_set.runs.create!(submitted_to: nil)
          expect(ResultDirectory.manual_submission_pre_process_script_path(run)).to be_exist
        end

        it "creates a preprocess executor" do
          @simulator.update_attribute(:pre_process_script, 'echo "Hello" > preprocess_result.txt')
          run = @param_set.runs.create!(submitted_to: nil)
          expect(ResultDirectory.manual_submission_pre_process_executor_path(run)).to be_exist
        end

        it "preprocess executor creates _preprocess.sh" do
          @simulator.update_attribute(:pre_process_script, 'echo "Hello" > preprocess_result.txt')
          run = @param_set.runs.create!(submitted_to: nil)
          pre_process_executor_path = ResultDirectory.manual_submission_pre_process_executor_path(run)
          cmd = "/bin/bash #{pre_process_executor_path.basename}"
          Dir.chdir(pre_process_executor_path.dirname) {
            system(cmd)
            _preprocess_path = Pathname.new(run.id).join("_preprocess.sh")
            expect(_preprocess_path).to be_exist
          }
        end

        it "preprocess executor creates _input.json" do
          @simulator.update_attribute(:support_input_json, true)
          @simulator.update_attribute(:pre_process_script, 'echo "Hello" > preprocess_result.txt')
          run = @param_set.runs.create!(submitted_to: nil)
          pre_process_executor_path = ResultDirectory.manual_submission_pre_process_executor_path(run)
          cmd = "/bin/bash #{pre_process_executor_path.basename}"
          Dir.chdir(pre_process_executor_path.dirname) {
            system(cmd)
            _input_json_path = Pathname.new(run.id).join("_input.json")
            expect(_input_json_path).to be_exist
            _preprocess_script_result = Pathname.new(run.id).join("preprocess_result.txt")
            expect(_preprocess_script_result).to be_exist
          }
        end
      end
    end
  end

  describe "removing runs_status_count_cache" do

    before(:each) do
      @param_set.runs_status_count
      expect(@param_set.reload.runs_status_count_cache).not_to be_nil
    end

    it "removes runs_status_count_cache when a new Run is created" do
      @param_set.runs.create!(@valid_attribute)
      expect(@param_set.reload.reload.runs_status_count_cache).to be_nil
    end

    it "removes runs_status_count_cache when status is changed" do
      run = @param_set.runs.first
      expect {
        run.update_attribute(:status, :finished)
      }.to change { @param_set.reload.runs_status_count_cache }.to(nil)
    end

    it "removes runs_status_count_cache when to_be_destroyed flag is set" do
      run = @param_set.runs.first
      expect {
        run.update_attribute(:to_be_destroyed, true)
      }.to change { @param_set.reload.runs_status_count_cache }.to(nil)
    end

    it "removes runs_status_count_cache when destroyed" do
      run = @param_set.runs.first
      expect {
        run.destroy
      }.to change { @param_set.reload.runs_status_count_cache }.to(nil)
    end

    it "does not change runs_status_count_cache when status is not changed" do
      run = @param_set.runs.first
      expect {
        run.update_attribute(:updated_at, DateTime.now)
      }.to_not change { @param_set.reload.runs_status_count_cache }
    end
  end
end
