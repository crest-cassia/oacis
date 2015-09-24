require 'spec_helper'

shared_examples_for JobScriptUtil do

  def run_test_script_in_temp_dir
    Dir.chdir(@temp_dir) {
      str = JobScriptUtil.script_for(@submittable, @host)
      script_path = 'test.sh'
      File.open( script_path, 'w') {|io| io.print str }
      system("bash #{script_path}")
    }
  end

  describe ".script_for" do

    it "job script creates _status.json and is valid" do
      run_test_script_in_temp_dir
      Dir.chdir(@temp_dir) {
        result_file = "#{@submittable.id}.tar.bz2"
        expect(File.exist?(result_file)).to be_truthy

        expect(File.directory?(@submittable.id.to_s)).to be_truthy

        system("tar xjf #{result_file}")
        json_path = File.join(@submittable.id.to_s, '_status.json')
        expect(File.exist?(json_path)).to be_truthy
        parsed = JSON.load(File.open(json_path))
        expect(parsed).to have_key("started_at")
        expect(parsed).to have_key("hostname")
        expect(parsed).to have_key("rc")
        expect(parsed).to have_key("finished_at")

        time_path = File.join(@submittable.id.to_s, '_time.txt')
        expect(File.exist?(time_path)).to be_truthy
      }
    end

    it "create a valid json file even if command has semi-colon at the end" do
      @executable.command = "echo hello;"
      @executable.save!
      run_test_script_in_temp_dir
      Dir.chdir(@temp_dir) {
        result_file = "#{@submittable.id}.tar.bz2"
        expect(File.exist?(result_file)).to be_truthy
      }
    end

    it "does not remove work_dir" do
      run_test_script_in_temp_dir
      work_dir = @temp_dir.join("#{@submittable.id}")
      archive = @temp_dir.join("#{@submittable.id}.tar.bz2")
      expect( File.directory?(work_dir) ).to be_truthy
      expect( File.exist?(archive) ).to be_truthy
    end

    it "removes _input dir when job finished successfully" do
      work_dir = @temp_dir.join(@submittable.id.to_s)
      input_dir = work_dir.join('_input')
      FileUtils.mkdir_p(input_dir)
      FileUtils.touch( input_dir.join('temp.txt') )

      run_test_script_in_temp_dir
      expect( File.directory?(input_dir) ).to be_falsey
    end

    it "does not remove _input dir when job failed" do
      work_dir = @temp_dir.join(@submittable.id.to_s)
      input_dir = work_dir.join('_input')
      FileUtils.mkdir_p(input_dir)
      FileUtils.touch( input_dir.join('temp.txt') )
      @executable.update_attribute(:command, 'invalid')

      run_test_script_in_temp_dir
      expect( File.directory?(input_dir) ).to be_truthy
    end

    it "set OACIS_MPI envs and do not call mpiexec when Simulator#support_mpi is true" do
      @executable.support_mpi = true
      @executable.save!
      @submittable.mpi_procs = 8
      script = JobScriptUtil.script_for(@submittable, @host)
      expect(script).to match(/OACIS_MPI_PROCS=8/)
      expect(script).to match(/OACIS_IS_MPI_JOB=true/)
      expect(script).not_to match(/mpiexec/)
    end

    it "do not set OACIS_MPI envs when Simulator#support_mpi is false" do
      @executable.support_mpi = false
      @executable.save!
      @submittable.mpi_procs = 8
      script = JobScriptUtil.script_for(@submittable, @host)
      expect(script).to match(/OACIS_IS_MPI_JOB=false/)
    end

    it "sets OMP_NUM_THREADS in the script" do
      @executable.support_omp = true
      @executable.save!
      @submittable.omp_threads = 8
      script = JobScriptUtil.script_for(@submittable, @host)
      expect(script).to match(/OACIS_OMP_THREADS=8/)
    end

    context "when host is nil" do

      it "does not cause an exception" do
        expect {
          JobScriptUtil.script_for(@submittable, nil)
        }.to_not raise_error
      end
    end
  end

  describe ".expand_result" do

    it "expand results" do
      @executable.command = "echo '{\"timeline\":[1,2,3]}' > _output.json"
      @executable.support_input_json = true
      @executable.save!
      run_test_script_in_temp_dir
      Dir.chdir(@temp_dir) {
        result_file = "#{@submittable.id}.tar.bz2"
        FileUtils.mv( result_file, @submittable.dir.join('..') )
        JobScriptUtil.expand_result_file(@submittable)

        # expand result properly
        expect(File.exist?(@submittable.dir.join('_stdout.txt'))).to be_truthy
        expect(File.exist?(@submittable.dir.join('_output.json'))).to be_truthy
        expect(File.exist?(@submittable.dir.join('..', "#{@submittable.id}.tar"))).to be_falsey
        expect(File.exist?(@submittable.dir.join('..', "#{@submittable.id}.tar.bz2"))).to be_truthy
      }
    end

    context "when archive is invalid archive" do

      it "raise error" do

        expect(JobScriptUtil).to receive(:system)
        expect($?).to receive(:to_i).and_return(1)
        expect {
          JobScriptUtil.expand_result_file(@submittable)
        }.to raise_error
      end

      it "update submittable.error_messages" do

        expect(JobScriptUtil).to receive(:system)
        expect($?).to receive(:to_i).and_return(1)
        expect {
          JobScriptUtil.expand_result_file(@submittable) rescue nil
        }.to change { @submittable.reload.error_messages }
      end
    end
  end

  describe ".update_run" do

    before(:each) do
      @executable.update_attribute(:command, "echo '{\"timeline\":[1,2,3]}' > _output.json")
      @executable.update_attribute(:support_input_json, true)
      run_test_script_in_temp_dir
      Dir.chdir(@temp_dir) {
        result_file = "#{@submittable.id}.tar.bz2"
        FileUtils.mv( result_file, @submittable.dir.join('..') )
      }
      JobScriptUtil.expand_result_file(@submittable)
    end

    it "parse _status.json" do

      JobScriptUtil.update_run(@submittable)

      # parse status
      @submittable.reload
      expect(@submittable.status).to eq :finished
      expect(@submittable.hostname).not_to be_empty
      expect(@submittable.started_at).to be_a(DateTime)
      expect(@submittable.finished_at).to be_a(DateTime)
      expect(@submittable.real_time).not_to be_nil
      expect(@submittable.cpu_time).not_to be_nil
      expect(@submittable.included_at).to be_a(DateTime)
    end

    context "when _status.json has invalid json format" do

      it "update status from :submitted to :failed" do

        parsed = JSON.load(File.open(@submittable.dir.join("_status.json")))
        File.open(@submittable.dir.join("_status.json"), "w") do |io|
          #puts a part of string
          io.puts parsed.to_json[0..10]
        end

        JobScriptUtil.update_run(@submittable)

        # parse status
        @submittable.reload
        expect(@submittable.status).to eq :failed
        expect(@submittable.hostname).to be_nil
        expect(@submittable.started_at).to be_nil
        expect(@submittable.finished_at).to be_nil
        expect(@submittable.real_time).not_to be_nil
        expect(@submittable.cpu_time).not_to be_nil
        expect(@submittable.included_at).to be_a(DateTime)
      end

      it "update submittable.error_messages" do

        parsed = JSON.load(File.open(@submittable.dir.join("_status.json")))
        File.open(@submittable.dir.join("_status.json"), "w") do |io|
          #puts a part of string
          io.puts parsed.to_json[0..10]
        end

        expect {
          JobScriptUtil.update_run(@submittable)
        }.to change { @submittable.reload.error_messages }

      end
    end

    it "parse _output.json which is not a Hash but a Float" do

      Dir.chdir(@submittable.dir) {
        result = 0.12345
        system("echo #{result} > _output.json")
      }

      JobScriptUtil.update_run(@submittable)

      # expand result properly
      expect(File.exist?(@submittable.dir.join('_output.json'))).to be_truthy

      # parse status
      @submittable.reload
      expect(@submittable.result).to eq Hash["result",0.12345]
    end

    it "parse _output.json which is not a Hash but a Boolean" do

      Dir.chdir(@submittable.dir) {
        result = false
        system("echo #{result} > _output.json")
      }

      JobScriptUtil.update_run(@submittable)

      # expand result properly
      expect(File.exist?(@submittable.dir.join('_output.json'))).to be_truthy

      # parse status
      @submittable.reload
      expect(@submittable.result).to eq Hash["result",false]
    end

    it "parse _output.json which is not a Hash but a String" do

      Dir.chdir(@submittable.dir) {
        result = "12345"
        system("echo \\\"#{result}\\\" > _output.json")
      }

      JobScriptUtil.update_run(@submittable)

      # expand result properly
      expect(File.exist?(@submittable.dir.join('_output.json'))).to be_truthy

      # parse status
      @submittable.reload
      expect(@submittable.result).to eq Hash["result","12345"]
    end

    it "parse _output.json which is not a Hash but a Array" do

      Dir.chdir(@submittable.dir) {
        result = [1,2,3]
        system("echo #{result} > _output.json")
      }

      JobScriptUtil.update_run(@submittable)

      # expand result properly
      expect(File.exist?(@submittable.dir.join('_output.json'))).to be_truthy

      # parse status
      @submittable.reload
      expect(@submittable.result).to eq Hash["result",[1,2,3]]
    end

    context "when _output.json has invalid json format" do

      it "do not update result" do

        parsed = JSON.load(File.open(@submittable.dir.join("_output.json")))
        File.open(@submittable.dir.join("_output.json"), "w") do |io|
          #puts a part of string
          io.puts parsed.to_json[0..10]
        end

        expect {
          JobScriptUtil.update_run(@submittable)
        }.not_to change { @submittable.result }

        # parse status
        @submittable.reload
        expect(@submittable.status).to eq :finished
        expect(@submittable.hostname).not_to be_nil
        expect(@submittable.started_at).to be_a(DateTime)
        expect(@submittable.finished_at).to be_a(DateTime)
        expect(@submittable.real_time).not_to be_nil
        expect(@submittable.cpu_time).not_to be_nil
        expect(@submittable.included_at).to be_a(DateTime)
      end

      it "update submittable.error_messages" do

        parsed = JSON.load(File.open(@submittable.dir.join("_output.json")))
        File.open(@submittable.dir.join("_output.json"), "w") do |io|
          #puts a part of string
          io.puts parsed.to_json[0..10]
        end

        expect {
          JobScriptUtil.update_run(@submittable)
        }.to change { @submittable.reload.error_messages }

      end
    end

    it "parse elapsed times" do

      time_str=<<EOS
real 0.30
user 0.20
sys 0.10
EOS
      File.open(@submittable.dir.join("_time.txt"), "w") do |io|
        io.puts time_str
      end

      JobScriptUtil.update_run(@submittable)

      @submittable.reload
      expect(@submittable.cpu_time).to eq 0.2
      expect(@submittable.real_time).to eq 0.3
    end

    context "when _time.txt has invalid format" do

      it "do not update result" do

        time_str=<<EOS
user 0.20
sys 0.10
EOS
        File.open(@submittable.dir.join("_time.txt"), "w") do |io|
          io.puts time_str
        end

        expect {
          JobScriptUtil.update_run(@submittable)
        }.not_to change { @submittable.real_time }

        # parse status
        @submittable.reload
        expect(@submittable.status).to eq :finished
        expect(@submittable.hostname).not_to be_nil
        expect(@submittable.started_at).to be_a(DateTime)
        expect(@submittable.finished_at).to be_a(DateTime)
        expect(@submittable.real_time).to be_nil
        expect(@submittable.cpu_time).not_to be_nil
        expect(@submittable.included_at).to be_a(DateTime)
      end

      it "update submittable.error_messages" do

        time_str=<<EOS
user 0.20
sys 0.10
EOS
        File.open(@submittable.dir.join("_time.txt"), "w") do |io|
          io.puts time_str
        end

        expect {
          JobScriptUtil.update_run(@submittable)
        }.to change { @submittable.reload.error_messages }

      end
    end

    context "when job return code other than 0" do

      it "parse failed jobs" do

        parsed = JSON.load(File.open(@submittable.dir.join("_status.json")))
        parsed["rc"] = "-1"
        File.open(@submittable.dir.join("_status.json"), "w") do |io|
          io.puts parsed.to_json
        end

        JobScriptUtil.update_run(@submittable)

        @submittable.reload
        expect(@submittable.status).to eq :failed
        expect(@submittable.hostname).not_to be_empty
        expect(@submittable.started_at).to be_a(DateTime)
        expect(@submittable.finished_at).to be_a(DateTime)
        expect(@submittable.real_time).not_to be_nil
        expect(@submittable.cpu_time).not_to be_nil
        expect(@submittable.included_at).to be_a(DateTime)
        expect(File.exist?(@submittable.dir.join('_stdout.txt'))).to be_truthy
      end

      it "update submittable.error_messages" do

        parsed = JSON.load(File.open(@submittable.dir.join("_status.json")))
        parsed["rc"] = "-1"
        File.open(@submittable.dir.join("_status.json"), "w") do |io|
          io.puts parsed.to_json
        end

        expect {
          JobScriptUtil.update_run(@submittable)
        }.to change { @submittable.reload.error_messages }

      end
    end

    it "parses simulator version printed by Simulator#print_version_command" do

      File.open(@submittable.dir.join("_version.txt"), "w") do |io|
        io.puts "version: 1.0.0"
      end

      JobScriptUtil.update_run(@submittable)

      @submittable.reload
      method = @executable.is_a?(Simulator) ? :simulator_version : :analyzer_version
      expect( @submittable.send(method) ).to eq "version: 1.0.0"
    end

    context "fails to parse simulator version" do

      it "update submittable.error_messages" do
        skip "not yet implemented"
      end
    end
  end
end

context "for Run" do

  before(:each) do
    sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 1)
    host = Host.where(name: "localhost").first
    sim.update_attribute(:executable_on, [host])
    run = sim.parameter_sets.first.runs.first
    @executable = sim
    @submittable = run
    @host = host
    @temp_dir = Pathname.new('__temp__')
    FileUtils.mkdir_p(@temp_dir)
    @host.work_base_dir = @temp_dir.expand_path
  end

  after(:each) do
    FileUtils.rm_r(@temp_dir) if File.directory?(@temp_dir)
  end

  it_should_behave_like JobScriptUtil
end

context "for Analysis" do

  before(:each) do
    sim = FactoryGirl.create(:simulator,
      parameter_sets_count: 1, runs_count: 1,
      analyzers_count: 1, run_analysis: false
      )
    run = sim.parameter_sets.first.runs.first
    host = Host.where(name: "localhost").first
    azr = sim.analyzers.first
    azr.update_attribute(:executable_on, [host])
    anl = run.analyses.create(analyzer: azr, submitted_to: host)

    @executable = azr
    @submittable = anl
    @host = host
    @temp_dir = Pathname.new('__temp__')
    FileUtils.mkdir_p(@temp_dir)
    @host.work_base_dir = @temp_dir.expand_path
  end

  after(:each) do
    FileUtils.rm_r(@temp_dir) if File.directory?(@temp_dir)
  end

  it_should_behave_like JobScriptUtil
end
