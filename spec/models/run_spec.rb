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

  describe "validations" do

    it "creates a Run with a valid attribute" do
      @param_set.runs.build(@valid_attribute).should be_valid
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

    it "seed must be unique" do
      seed_val = @param_set.runs.first.seed
      @valid_attribute.update(seed: seed_val)
      @param_set.runs.build(@valid_attribute).should_not be_valid
    end

    it "status must be either :created, :submitted, :running, :failed, :finished, or :cancelled" do
      run = @param_set.runs.build(@valid_attribute)
      run.status = :unknown
      run.should_not be_valid
    end

    it "mpi_procs must be present" do
      run = @param_set.runs.build(@valid_attribute)
      run.mpi_procs = nil
      run.should_not be_valid
    end

    it "omp_threads must be present" do
      run = @param_set.runs.build(@valid_attribute)
      run.omp_threads = nil
      run.should_not be_valid
    end

    it "mpi_procs must between Host#min_mpi_procs and Host#max_mpi_procs" do
      run = @param_set.runs.build(@valid_attribute)
      host = run.submitted_to
      host.update_attributes(min_mpi_procs: 1, max_mpi_procs: 256)
      run.mpi_procs = 256
      run.should be_valid
      run.mpi_procs = 512
      run.should_not be_valid
    end

    it "skips validation of mpi_procs for a persisted document" do
      run = @param_set.runs.build(@valid_attribute)
      host = run.submitted_to
      host.update_attributes(min_mpi_procs: 1, max_mpi_procs: 256)
      run.mpi_procs = 256
      run.save!
      host.update_attribute(:max_mpi_procs, 128)
      run.should be_valid
    end

    it "omp_threads must between Host#min_omp_threads and Host#max_omp_threads" do
      run = @param_set.runs.build(@valid_attribute)
      host = run.submitted_to
      host.update_attributes(min_omp_threads: 1, max_omp_threads: 256)
      run.omp_threads = 256
      run.should be_valid
      run.omp_threads = 512
      run.should_not be_valid
    end

    it "skips validation of omp_threads for a persisted document" do
      run = @param_set.runs.build(@valid_attribute)
      host = run.submitted_to
      host.update_attributes(min_omp_threads: 1, max_omp_threads: 256)
      run.omp_threads = 256
      run.save!
      host.update_attribute(:max_omp_threads, 128)
      run.should be_valid
    end

    it "assigns a priority by default" do
      run = @param_set.runs.create
      run.priority.should be_a(Integer)
    end

    it "automatically assigned priority is 1" do
      run = @param_set.runs.create
      run.priority.should eq 1
    end

   describe "'host_parameters' field" do

      before(:each) do
        header = <<-EOS
#!/bin/bash
# node:<%= node %>
# proc:<%= mpi_procs %>
EOS
        template = JobScriptUtil::DEFAULT_TEMPLATE.sub(/#!\/bin\/bash/, header)
        hpds = [ HostParameterDefinition.new(key: "node", default: "x", format: '\w+') ]
        @host = FactoryGirl.create(:host, template: template, host_parameter_definitions: hpds)
      end

      it "is valid when host_parameters are properly given" do
        run = @param_set.runs.build(@valid_attribute)
        run.submitted_to = @host
        run.mpi_procs = 8
        run.host_parameters = {"node" => "abc"}
        run.should be_valid
      end

      it "is invalid when all the host_parameters are not specified" do
        run = @param_set.runs.build(@valid_attribute)
        run.submitted_to = @host
        run.mpi_procs = 8
        run.host_parameters = {}
        run.should_not be_valid
      end

      it "is valid when host_parameters have rendundant keys" do
        run = @param_set.runs.build(@valid_attribute)
        run.submitted_to = @host
        run.mpi_procs = 8
        run.omp_threads = 8
        run.host_parameters = {"node" => "abd", "shape" => "xyz"}
        run.should be_valid
      end

      it "is invalid when host_parameters does not match the defined format" do
        run = @param_set.runs.build(@valid_attribute)
        run.submitted_to = @host
        run.host_parameters = {"node" => "!!!"}
        run.should_not be_valid
      end

      it "skips validation for a persisted run" do
        run = @param_set.runs.build(@valid_attribute)
        run.submitted_to = @host
        run.mpi_procs = 8
        run.host_parameters = {"node" => "abc"}
        run.save!
        new_template = <<-EOS
#!/bin/bash
# new_var: <%= new_var %>
EOS
        @host.update_attribute(:template, new_template)
        run.should be_valid
      end
    end

    it "submitted_to can be nil" do
      run = @param_set.runs.build(@valid_attribute.update({submitted_to: nil}))
      run.should be_valid
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

    it "returns simulator even when run is not saved" do
      run = @param_set.runs.build
      run.simulator.should be_a(Simulator)
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
      FileTest.directory?(ResultDirectory.run_path(run)).should be_truthy
    end

    it "is not created when validation fails" do
      sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 1)
      prm = sim.parameter_sets.first
      seed_val = prm.runs.first.seed
      @valid_attribute.update(seed: seed_val)

      prev_count = Dir.entries(ResultDirectory.parameter_set_path(prm)).size
      prm.runs.create(@valid_attribute)
      prev_count = Dir.entries(ResultDirectory.parameter_set_path(prm)).size.should == prev_count
    end

    it "is removed when the item is destroyed" do
      sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 1)
      run = sim.parameter_sets.first.runs.first
      dir_path = run.dir
      run.destroy
      FileTest.directory?(dir_path).should be_falsey
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
      @temp_files[0..1].each do |f|
        res.should include(f)
      end
      res.should include(@temp_dir)
      res.should_not include(@temp_files[2])
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

    it "deletes job script and _input.json created for manual submission" do
      sim = @run.simulator
      sim.update_attribute(:support_input_json, true)
      run = sim.parameter_sets.first.runs.create(submitted_to: nil)
      sh_path = ResultDirectory.manual_submission_job_script_path(run)
      json_path = ResultDirectory.manual_submission_input_json_path(run)

      sh_path.should be_exist
      json_path.should be_exist
      run.destroy
      sh_path.should_not be_exist
      json_path.should_not be_exist
    end

    it "deletes preprocess script and preprocess executor created for manual submission" do
      sim = @run.simulator
      sim.update_attribute(:pre_process_script, 'echo "Hello" > preprocess_result.txt')
      run = sim.parameter_sets.first.runs.create(submitted_to: nil)
      pre_process_script_path = ResultDirectory.manual_submission_pre_process_script_path(run)
      pre_process_executor_path = ResultDirectory.manual_submission_pre_process_executor_path(run)

      pre_process_script_path.should be_exist
      pre_process_executor_path.should be_exist
      run.destroy
      pre_process_script_path.should_not be_exist
      pre_process_executor_path.should_not be_exist
    end

    context "when status is :submitted or :running" do

      before(:each) do
        @run.status = :submitted
      end

      it "calls cancel if status is :submitted or :running" do
        @run.should_receive(:cancel)
        @run.destroy
      end

      it "does not destroy run if status is :submitted or :running" do
        expect {
          @run.destroy
        }.to_not change { Run.count }
        @run.status.should eq :cancelled
        @run.parameter_set.should be_nil
      end

      it "deletes run_directory and archived_result_file when cancel is called" do
        run_dir = @run.dir
        archive = @run.archived_result_path
        FileUtils.touch(archive)
        @run.destroy
        File.exist?(run_dir).should be_falsey
        File.exist?(archive).should be_falsey
      end

      it "does not destroy run even if #destroy is called twice" do
        expect {
          @run.destroy
          @run.destroy
        }.to_not change { Run.count }
        @run.status.should eq :cancelled
      end
    end
  end

  describe "after_create callbacks" do

    it "removes host_parameters not necessary for the host" do
      template = <<EOS
#!/bin/bash
# foobar: <%= foobar %>
EOS
      hpds = [ HostParameterDefinition.new(key: "foobar") ]
      host = FactoryGirl.create(:host, template: template, host_parameter_definitions: hpds)
      r_params = {"foobar" => 1, "baz" => 2}
      run = @param_set.runs.build(submitted_to: host, host_parameters: r_params)
      run.save!
      run.host_parameters.should eq ({"foobar" => 1})
    end

    it "sets job script" do
      run = @param_set.runs.build(submitted_to: Host.first)
      run.job_script.should_not be_present
      run.save!
      run.job_script.should be_present
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
        ResultDirectory.manual_submission_job_script_path(run).should be_exist
      end

      it "create _input.json" do
        @simulator.update_attribute(:support_input_json, true)
        run = @param_set.runs.create!(submitted_to: nil)
        ResultDirectory.manual_submission_input_json_path(run).should be_exist
      end

      context "when simulator.pre_process exists" do

        it "creates a preprocess script" do
          @simulator.update_attribute(:pre_process_script, 'echo "Hello" > preprocess_result.txt')
          run = @param_set.runs.create!(submitted_to: nil)
          ResultDirectory.manual_submission_pre_process_script_path(run).should be_exist
        end

        it "creates a preprocess executor" do
          @simulator.update_attribute(:pre_process_script, 'echo "Hello" > preprocess_result.txt')
          run = @param_set.runs.create!(submitted_to: nil)
          ResultDirectory.manual_submission_pre_process_executor_path(run).should be_exist
        end

        it "preprocess executor creates _preprocess.sh" do
          @simulator.update_attribute(:pre_process_script, 'echo "Hello" > preprocess_result.txt')
          run = @param_set.runs.create!(submitted_to: nil)
          pre_process_executor_path = ResultDirectory.manual_submission_pre_process_executor_path(run)
          cmd = "/bin/bash #{pre_process_executor_path.basename}"
          Dir.chdir(pre_process_executor_path.dirname) {
            system(cmd)
            _preprocess_path = Pathname.new(run.id).join("_preprocess.sh")
            _preprocess_path.should be_exist
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
            _input_json_path.should be_exist
            _preprocess_script_result = Pathname.new(run.id).join("preprocess_result.txt")
            _preprocess_script_result.should be_exist
          }
        end
      end
    end
  end

  describe "removing runs_status_count_cache" do

    before(:each) do
      @param_set.runs_status_count
      @param_set.reload.runs_status_count_cache.should_not be_nil
    end

    it "removes runs_status_count_cache when a new Run is created" do
      @param_set.runs.create!(@valid_attribute)
      @param_set.reload.runs_status_count_cache.should be_nil
    end

    it "removes runs_status_count_cache when status is changed" do
      run = @param_set.runs.first
      run.status = :finished
      run.save!
      @param_set.reload.runs_status_count_cache.should be_nil
    end

    it "removes runs_status_count_cache when destroyed" do
      run = @param_set.runs.first
      run.destroy
      @param_set.reload.runs_status_count_cache.should be_nil
    end

    it "does not change runs_status_count_cache when status is not changed" do
      run = @param_set.runs.first
      run.updated_at = DateTime.now
      run.save!
      @param_set.reload.runs_status_count_cache.should_not be_nil
    end
  end
end
