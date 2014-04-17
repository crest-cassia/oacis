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
        File.exist?(result_file).should be_true

        File.directory?(@run.id.to_s).should be_false

        system("tar xjf #{result_file}")
        json_path = File.join(@run.id.to_s, '_status.json')
        File.exist?(json_path).should be_true
        parsed = JSON.load(File.open(json_path))
        parsed.should have_key("started_at")
        parsed.should have_key("hostname")
        parsed.should have_key("rc")
        parsed.should have_key("finished_at")

        time_path = File.join(@run.id.to_s, '_time.txt')
        File.exist?(time_path).should be_true
      }
    end

    it "create a valid json file even if command has semi-colon at the end" do
      @sim.command = "echo hello;"
      @sim.save!
      run_test_script_in_temp_dir
      Dir.chdir(@temp_dir) {
        result_file = "#{@run.id}.tar.bz2"
        File.exist?(result_file).should be_true
      }
    end

    it "renders a template" do
      @host.template = <<EOS
#!/bin/sh
# foobar: <%= foobar %>
# node: <%= mpi_procs / 4 %>
# mpi_procs: <%= mpi_procs %>
EOS
      @run.mpi_procs = 8
      @run.host_parameters = {"foobar" => "abc"}
      script = JobScriptUtil.script_for(@run, @host)
      script.should match(/bin\/sh/)
      script.should match(/foobar: abc/)
      script.should match(/node: 2/)
      script.should match(/mpi_procs: 8/)
    end

    it "calls mpiexec when Simulator#support_mpi is true" do
      @sim.support_mpi = true
      @sim.save!
      @run.mpi_procs = 8
      script = JobScriptUtil.script_for(@run, @host)
      script.should match(/OACIS_MPI_PROCS=8/)
      script.should match(/OACIS_IS_MPI_JOB=true/)
    end

    it "does not call insert mpiexec when Simulator#support_mpi is false" do
      @sim.support_mpi = false
      @sim.save!
      @run.mpi_procs = 8
      script = JobScriptUtil.script_for(@run, @host)
      script.should match(/OACIS_IS_MPI_JOB=false/)
    end

    it "sets OMP_NUM_THREADS in the script" do
      @sim.support_omp = true
      @sim.save!
      @run.omp_threads = 8
      script = JobScriptUtil.script_for(@run, @host)
      script.should match(/OACIS_OMP_THREADS=8/)
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
        File.exist?(@run.dir.join('_stdout.txt')).should be_true
        File.exist?(@run.dir.join('_output.json')).should be_true
        File.exist?(@run.dir.join('..', "#{@run.id}.tar")).should be_false
        File.exist?(@run.dir.join('..', "#{@run.id}.tar.bz2")).should be_true
      }
    end

    context "when archive is invalid archive" do
      it "raise error" do
        Dir.chdir(@temp_dir) {
          system("echo 1.2345 > #{@run.id}.tar.bz2")
          result_file = "#{@run.id}.tar.bz2"
          FileUtils.mv( result_file, @run.dir.join('..') )
          expect {
            JobScriptUtil.expand_result_file(@run)
          }.to raise_error
        }
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
      @run.status.should eq :finished
      @run.hostname.should_not be_empty
      @run.started_at.should be_a(DateTime)
      @run.finished_at.should be_a(DateTime)
      @run.real_time.should_not be_nil
      @run.cpu_time.should_not be_nil
      @run.included_at.should be_a(DateTime)
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
        @run.status.should eq :created
        @run.hostname.should be_nil
        @run.started_at.should be_nil
        @run.finished_at.should be_nil
        @run.real_time.should_not be_nil
        @run.cpu_time.should_not be_nil
        @run.included_at.should be_a(DateTime)
      end
    end

    it "parse _output.json which is not a Hash but a Float" do

      Dir.chdir(@run.dir) {
        result = 0.12345
        system("echo #{result} > _output.json")
      }

      JobScriptUtil.update_run(@run)

      # expand result properly
      File.exist?(@run.dir.join('_output.json')).should be_true

      # parse status
      @run.reload
      @run.result.should eq Hash["result",0.12345]
    end

    it "parse _output.json which is not a Hash but a Boolean" do

      Dir.chdir(@run.dir) {
        result = false
        system("echo #{result} > _output.json")
      }

      JobScriptUtil.update_run(@run)

      # expand result properly
      File.exist?(@run.dir.join('_output.json')).should be_true

      # parse status
      @run.reload
      @run.result.should eq Hash["result",false]
    end

    it "parse _output.json which is not a Hash but a String" do

      Dir.chdir(@run.dir) {
        result = "12345"
        system("echo \\\"#{result}\\\" > _output.json")
      }

      JobScriptUtil.update_run(@run)

      # expand result properly
      File.exist?(@run.dir.join('_output.json')).should be_true

      # parse status
      @run.reload
      @run.result.should eq Hash["result","12345"]
    end

    it "parse _output.json which is not a Hash but a Array" do

      Dir.chdir(@run.dir) {
        result = [1,2,3]
        system("echo #{result} > _output.json")
      }

      JobScriptUtil.update_run(@run)

      # expand result properly
      File.exist?(@run.dir.join('_output.json')).should be_true

      # parse status
      @run.reload
      @run.result.should eq Hash["result",[1,2,3]]
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
        @run.status.should eq :finished
        @run.hostname.should_not be_nil
        @run.started_at.should be_a(DateTime)
        @run.finished_at.should be_a(DateTime)
        @run.real_time.should_not be_nil
        @run.cpu_time.should_not be_nil
        @run.included_at.should be_a(DateTime)
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
      @run.cpu_time.should eq 0.2
      @run.real_time.should eq 0.3
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
        @run.status.should eq :finished
        @run.hostname.should_not be_nil
        @run.started_at.should be_a(DateTime)
        @run.finished_at.should be_a(DateTime)
        @run.real_time.should be_nil
        @run.cpu_time.should_not be_nil
        @run.included_at.should be_a(DateTime)
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
      @run.status.should eq :failed
      @run.hostname.should_not be_empty
      @run.started_at.should be_a(DateTime)
      @run.finished_at.should be_a(DateTime)
      @run.real_time.should_not be_nil
      @run.cpu_time.should_not be_nil
      @run.included_at.should be_a(DateTime)
      File.exist?(@run.dir.join('_stdout.txt')).should be_true
    end

    it "parses simulator version printed by Simulator#print_version_command" do

      File.open(@run.dir.join("_version.txt"), "w") do |io|
        io.puts "simulator version: 1.0.0"
      end

      JobScriptUtil.update_run(@run)

      @run.reload
      @run.simulator_version.should eq "simulator version: 1.0.0"
    end
  end
end
