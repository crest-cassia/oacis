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

    it "inserts expanded header" do
      pending "not yet implemented"
      @host.template = <<EOS
#!/bin/sh
# foobar: <%= foobar %>
# mpi_procs: <%= mpi_procs %>
EOS
      @run.mpi_procs = 8
      @run.host_parameters = {"foobar" => "abc"}
      script = JobScriptUtil.script_for(@run, @host)
      script.should match(/bin\/sh/)
      script.should match(/foobar: abc/)
      script.should match(/mpi_procs: 8/)
    end

    it "calls mpiexec when Simulator#support_mpi is true" do
      @sim.support_mpi = true
      @sim.save!
      @run.mpi_procs = 8
      script = JobScriptUtil.script_for(@run, @host)
      script.should match(/CM_MPI_PROCS=8/)
      script.should match(/CM_IS_MPI_JOB=true/)
    end

    it "does not call insert mpiexec when Simulator#support_mpi is false" do
      @sim.support_mpi = false
      @sim.save!
      @run.mpi_procs = 8
      script = JobScriptUtil.script_for(@run, @host)
      script.should match(/CM_IS_MPI_JOB=false/)
    end

    it "sets OMP_NUM_THREADS in the script" do
      @sim.support_omp = true
      @sim.save!
      @run.omp_threads = 8
      script = JobScriptUtil.script_for(@run, @host)
      script.should match(/CM_OMP_THREADS=8/)
    end
  end

  describe ".expand_result_file_and_update_run" do

    it "expand results and parse _status.json" do
      @sim.command = "echo '[1,2,3]' > _output.json"
      @sim.save!
      run_test_script_in_temp_dir
      Dir.chdir(@temp_dir) {
        result_file = "#{@run.id}.tar.bz2"
        FileUtils.mv( result_file, @run.dir.join('..') )
        JobScriptUtil.expand_result_file_and_update_run(@run)

        # expand result properly
        File.exist?(@run.dir.join('_stdout.txt')).should be_true
        File.exist?(@run.dir.join('_output.json')).should be_true
        File.exist?(@run.dir.join('..', "#{@run.id}.tar")).should be_false
        File.exist?(@run.dir.join('..', "#{@run.id}.tar.bz2")).should be_true

        # parse status
        @run.reload
        @run.status.should eq :finished
        @run.hostname.should_not be_empty
        @run.started_at.should be_a(DateTime)
        @run.finished_at.should be_a(DateTime)
        @run.real_time.should_not be_nil
        @run.cpu_time.should_not be_nil
        @run.included_at.should be_a(DateTime)
        @run.result.should eq [1,2,3]
      }
    end

    it "parse elapsed times" do
      @sim.command = "sleep 1"
      @sim.save!
      run_test_script_in_temp_dir
      Dir.chdir(@temp_dir) {
        result_file = "#{@run.id}.tar.bz2"
        FileUtils.mv( result_file, @run.dir.join('..') )
        JobScriptUtil.expand_result_file_and_update_run(@run)

        @run.reload
        @run.cpu_time.should be_within(0.2).of(0.0)
        @run.real_time.should be_within(0.2).of(1.0)
      }
    end

    it "parse failed jobs" do
      @sim.command = "INVALID"
      @sim.save!
      run_test_script_in_temp_dir
      Dir.chdir(@temp_dir) {
        result_file = "#{@run.id}.tar.bz2"
        FileUtils.mv( result_file, @run.dir.join('..') )
        JobScriptUtil.expand_result_file_and_update_run(@run)

        @run.reload
        @run.status.should eq :failed
        @run.hostname.should_not be_empty
        @run.started_at.should be_a(DateTime)
        @run.finished_at.should be_a(DateTime)
        @run.real_time.should_not be_nil
        @run.cpu_time.should_not be_nil
        @run.included_at.should be_a(DateTime)
        File.exist?(@run.dir.join('_stdout.txt')).should be_true
      }
    end
  end

  describe ".extract_parameters" do

    it "returns array of parameters used in the template" do
      template = <<-EOS
#!/bin/bash
#
#PJM --rsc-list "node=<%= node %>"
#PJM --rsc-list "elapse=<%= elapse %>"
#PJM --rsc-list "rscgrp=<%= rscgrp %>"
#PJM --stg-transfiles all
#PJM --mpi "use-rankdir"
#PJM --mpi "shape=<%= node %>"
#PJM --mpi "proc=<%= mpi_procs %>"
#PJM --stgin "<%= stgin %>"
#PJM -s
#
      EOS
      arr = JobScriptUtil.extract_parameters(template)
      arr.should eq %w(node elapse rscgrp mpi_procs stgin)
    end
  end

  describe ".expand_parameters" do

    it "returns header expanded by the given runtime parameters" do
      template = <<-EOS
#!/bin/bash
#
#PJM --rsc-list "node=<%= node %>"
#PJM --rsc-list "elapse=<%= elapse %>"
#PJM --rsc-list "rscgrp=<%= rscgrp %>"
#PJM --stg-transfiles all
#PJM --mpi "use-rankdir"
#PJM --mpi "shape=<%= node %>"
#PJM --mpi "proc=<%= mpi_procs %>"
#PJM --stgin "<%= stgin %>"
#PJM -s
#
      EOS

      variables = { "node" => "16",
                    "elapse" => "3:00:00",
                    "rscgrp" => "small",
                    "mpi_procs" => "128",
                    "stgin" => 'rank=* ./rank%r/* %r:./'
                  }
      expanded = JobScriptUtil.expand_parameters(template, variables)

      header = <<-EOS
#!/bin/bash
#
#PJM --rsc-list "node=16"
#PJM --rsc-list "elapse=3:00:00"
#PJM --rsc-list "rscgrp=small"
#PJM --stg-transfiles all
#PJM --mpi "use-rankdir"
#PJM --mpi "shape=16"
#PJM --mpi "proc=128"
#PJM --stgin "rank=* ./rank%r/* %r:./"
#PJM -s
#
      EOS
      expanded.should eq header
    end
  end
end
