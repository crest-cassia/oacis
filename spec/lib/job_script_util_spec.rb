require 'spec_helper'

describe JobScriptUtil do

  before(:each) do
    @sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 1)
    @run = @sim.parameter_sets.first.runs.first
    @temp_dir = Pathname.new('__temp__')
    FileUtils.mkdir_p(@temp_dir)
    @host = Host.where(name: "localhost").first
    @host.work_base_dir = @temp_dir.expand_path
  end

  after(:each) do
    FileUtils.rm_r(@temp_dir) if File.directory?(@temp_dir)
  end

  def run_test_script_in_temp_dir
    Dir.chdir(@temp_dir) {
      str = JobScriptUtil.script_for(@run, @host)
      script_path = 'test.sh'
      File.open( script_path, 'w') {|io| io.print str }
      system("bash #{script_path}")
    }
  end

  describe ".script_for" do

    it "job script creates _status.json and is valid" do
      run_test_script_in_temp_dir
      Dir.chdir(@temp_dir) {
        result_file = "#{@run.id}.tar.bz2"
        expect(File.exist?(result_file)).to be_truthy

        expect(File.directory?(@run.id.to_s)).to be_falsey

        system("tar xjf #{result_file}")
        json_path = File.join(@run.id.to_s, '_status.json')
        expect(File.exist?(json_path)).to be_truthy
        parsed = JSON.load(File.open(json_path))
        expect(parsed).to have_key("started_at")
        expect(parsed).to have_key("hostname")
        expect(parsed).to have_key("rc")
        expect(parsed).to have_key("finished_at")

        time_path = File.join(@run.id.to_s, '_time.txt')
        expect(File.exist?(time_path)).to be_truthy
      }
    end

    it "create a valid json file even if command has semi-colon at the end" do
      @sim.command = "echo hello;"
      @sim.save!
      run_test_script_in_temp_dir
      Dir.chdir(@temp_dir) {
        result_file = "#{@run.id}.tar.bz2"
        expect(File.exist?(result_file)).to be_truthy
      }
    end

    it "calls mpiexec when Simulator#support_mpi is true" do
      @sim.support_mpi = true
      @sim.save!
      @run.mpi_procs = 8
      script = JobScriptUtil.script_for(@run, @host)
      expect(script).to match(/OACIS_MPI_PROCS=8/)
      expect(script).to match(/OACIS_IS_MPI_JOB=true/)
    end

    it "does not call insert mpiexec when Simulator#support_mpi is false" do
      @sim.support_mpi = false
      @sim.save!
      @run.mpi_procs = 8
      script = JobScriptUtil.script_for(@run, @host)
      expect(script).to match(/OACIS_IS_MPI_JOB=false/)
    end

    it "sets OMP_NUM_THREADS in the script" do
      @sim.support_omp = true
      @sim.save!
      @run.omp_threads = 8
      script = JobScriptUtil.script_for(@run, @host)
      expect(script).to match(/OACIS_OMP_THREADS=8/)
    end

    context "when host is nil" do

      it "does not cause an exception" do
        expect {
          JobScriptUtil.script_for(@run, nil)
        }.to_not raise_error
      end
    end
  end

  describe ".expand_result" do

    it "expand results" do
      @sim.command = "echo '{\"timeline\":[1,2,3]}' > _output.json"
      @sim.support_input_json = true
      @sim.save!
      run_test_script_in_temp_dir
      Dir.chdir(@temp_dir) {
        result_file = "#{@run.id}.tar.bz2"
        FileUtils.mv( result_file, @run.dir.join('..') )
        JobScriptUtil.expand_result_file(@run)

        # expand result properly
        expect(File.exist?(@run.dir.join('_stdout.txt'))).to be_truthy
        expect(File.exist?(@run.dir.join('_output.json'))).to be_truthy
        expect(File.exist?(@run.dir.join('..', "#{@run.id}.tar"))).to be_falsey
        expect(File.exist?(@run.dir.join('..', "#{@run.id}.tar.bz2"))).to be_truthy
      }
    end

    context "when archive is invalid archive" do
      it "raise error" do
        expect(JobScriptUtil).to receive(:system)
        expect($?).to receive(:to_i).and_return(1)
        expect {
          JobScriptUtil.expand_result_file(@run)
        }.to raise_error
      end
    end
  end

  describe ".update_run" do

    before(:each) do
      @sim.command = "echo '{\"timeline\":[1,2,3]}' > _output.json"
      @sim.support_input_json = true
      @sim.save!
      run_test_script_in_temp_dir
      Dir.chdir(@temp_dir) {
        result_file = "#{@run.id}.tar.bz2"
        FileUtils.mv( result_file, @run.dir.join('..') )
      }
      JobScriptUtil.expand_result_file(@run)
    end

    it "parse _status.json" do

      JobScriptUtil.update_run(@run)

      # parse status
      @run.reload
      expect(@run.status).to eq :finished
      expect(@run.hostname).not_to be_empty
      expect(@run.started_at).to be_a(DateTime)
      expect(@run.finished_at).to be_a(DateTime)
      expect(@run.real_time).not_to be_nil
      expect(@run.cpu_time).not_to be_nil
      expect(@run.included_at).to be_a(DateTime)
    end

    context "when _status.json has invalid json format" do

      it "do not update status" do

        parsed = JSON.load(File.open(@run.dir.join("_status.json")))
        File.open(@run.dir.join("_status.json"), "w") do |io|
          #puts a part of string
          io.puts parsed.to_json[0..10]
        end

        JobScriptUtil.update_run(@run)

        # parse status
        @run.reload
        expect(@run.status).to eq :created
        expect(@run.hostname).to be_nil
        expect(@run.started_at).to be_nil
        expect(@run.finished_at).to be_nil
        expect(@run.real_time).not_to be_nil
        expect(@run.cpu_time).not_to be_nil
        expect(@run.included_at).to be_a(DateTime)
      end
    end

    it "parse _output.json which is not a Hash but a Float" do

      Dir.chdir(@run.dir) {
        result = 0.12345
        system("echo #{result} > _output.json")
      }

      JobScriptUtil.update_run(@run)

      # expand result properly
      expect(File.exist?(@run.dir.join('_output.json'))).to be_truthy

      # parse status
      @run.reload
      expect(@run.result).to eq Hash["result",0.12345]
    end

    it "parse _output.json which is not a Hash but a Boolean" do

      Dir.chdir(@run.dir) {
        result = false
        system("echo #{result} > _output.json")
      }

      JobScriptUtil.update_run(@run)

      # expand result properly
      expect(File.exist?(@run.dir.join('_output.json'))).to be_truthy

      # parse status
      @run.reload
      expect(@run.result).to eq Hash["result",false]
    end

    it "parse _output.json which is not a Hash but a String" do

      Dir.chdir(@run.dir) {
        result = "12345"
        system("echo \\\"#{result}\\\" > _output.json")
      }

      JobScriptUtil.update_run(@run)

      # expand result properly
      expect(File.exist?(@run.dir.join('_output.json'))).to be_truthy

      # parse status
      @run.reload
      expect(@run.result).to eq Hash["result","12345"]
    end

    it "parse _output.json which is not a Hash but a Array" do

      Dir.chdir(@run.dir) {
        result = [1,2,3]
        system("echo #{result} > _output.json")
      }

      JobScriptUtil.update_run(@run)

      # expand result properly
      expect(File.exist?(@run.dir.join('_output.json'))).to be_truthy

      # parse status
      @run.reload
      expect(@run.result).to eq Hash["result",[1,2,3]]
    end

    context "when _output.json has invalid json format" do

      it "do not update result" do

        parsed = JSON.load(File.open(@run.dir.join("_output.json")))
        File.open(@run.dir.join("_output.json"), "w") do |io|
          #puts a part of string
          io.puts parsed.to_json[0..10]
        end

        expect {
          JobScriptUtil.update_run(@run)
        }.not_to change { @run.result }

        # parse status
        @run.reload
        expect(@run.status).to eq :finished
        expect(@run.hostname).not_to be_nil
        expect(@run.started_at).to be_a(DateTime)
        expect(@run.finished_at).to be_a(DateTime)
        expect(@run.real_time).not_to be_nil
        expect(@run.cpu_time).not_to be_nil
        expect(@run.included_at).to be_a(DateTime)
      end
    end

    it "parse elapsed times" do

      time_str=<<EOS
real 0.30
user 0.20
sys 0.10
EOS
      File.open(@run.dir.join("_time.txt"), "w") do |io|
        io.puts time_str
      end

      JobScriptUtil.update_run(@run)

      @run.reload
      expect(@run.cpu_time).to eq 0.2
      expect(@run.real_time).to eq 0.3
    end

    context "when _time.txt has invalid format" do

      it "do not update result" do

        time_str=<<EOS
user 0.20
sys 0.10
EOS
        File.open(@run.dir.join("_time.txt"), "w") do |io|
          io.puts time_str
        end

        expect {
          JobScriptUtil.update_run(@run)
        }.not_to change { @run.real_time }

        # parse status
        @run.reload
        expect(@run.status).to eq :finished
        expect(@run.hostname).not_to be_nil
        expect(@run.started_at).to be_a(DateTime)
        expect(@run.finished_at).to be_a(DateTime)
        expect(@run.real_time).to be_nil
        expect(@run.cpu_time).not_to be_nil
        expect(@run.included_at).to be_a(DateTime)
      end
    end

    it "parse failed jobs" do

      parsed = JSON.load(File.open(@run.dir.join("_status.json")))
      parsed["rc"] = "-1"
      File.open(@run.dir.join("_status.json"), "w") do |io|
        io.puts parsed.to_json
      end

      JobScriptUtil.update_run(@run)

      @run.reload
      expect(@run.status).to eq :failed
      expect(@run.hostname).not_to be_empty
      expect(@run.started_at).to be_a(DateTime)
      expect(@run.finished_at).to be_a(DateTime)
      expect(@run.real_time).not_to be_nil
      expect(@run.cpu_time).not_to be_nil
      expect(@run.included_at).to be_a(DateTime)
      expect(File.exist?(@run.dir.join('_stdout.txt'))).to be_truthy
    end

    it "parses simulator version printed by Simulator#print_version_command" do

      File.open(@run.dir.join("_version.txt"), "w") do |io|
        io.puts "simulator version: 1.0.0"
      end

      JobScriptUtil.update_run(@run)

      @run.reload
      expect(@run.simulator_version).to eq "simulator version: 1.0.0"
    end
  end
end
