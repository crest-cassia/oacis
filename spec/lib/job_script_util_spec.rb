require 'spec_helper'

describe JobScriptUtil do

  before(:each) do
      @sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 1)
      @run = @sim.parameter_sets.first.runs.first
      @temp_dir = Pathname.new('__temp__')
      FileUtils.mkdir_p(@temp_dir)
      @host = FactoryGirl.create(:localhost, work_base_dir: @temp_dir.expand_path)
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
end
