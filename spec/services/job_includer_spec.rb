require 'spec_helper'

describe JobIncluder do

  def make_valid_archive_file(run, keep_work_dir = false)
    Dir.chdir(@temp_dir) {
      work_dir = Pathname.new(run.id.to_s)
      make_valid_work_dir(work_dir)
      archive_path = Pathname.new("#{run.id}.tar.bz2")
      system("tar cjf #{archive_path} #{work_dir}")
      FileUtils.remove_entry_secure(work_dir) unless keep_work_dir
      @archive_full_path = archive_path.expand_path
    }
  end

  def make_valid_work_dir(work_dir)
    FileUtils.mkdir(work_dir)
    Dir.chdir(work_dir) {
      File.open("_status.json", 'w') {|io|
        status = {
          "hostname" => "hostXXX",
          "started_at" => DateTime.now, "finished_at" => DateTime.now,
          "rc" => 0
        }
        io.puts status.to_json
        io.flush
      }
      File.open("_time.txt", 'w') {|io|
        io.puts "real 10.00\nuser 8.00\nsys 2.00"
        io.flush
      }
      FileUtils.touch("_stdout.txt")
    }
  end

  before(:each) do
    @sim = FactoryGirl.create(:simulator,
                              parameter_sets_count: 1, runs_count: 0,
                              command: "sleep 1")
    azr = FactoryGirl.create(:analyzer, simulator: @sim, auto_run: :yes, run_analysis: false)

    @temp_dir = Pathname.new( Dir.mktmpdir )
  end

  after(:each) do
    FileUtils.remove_entry_secure(@temp_dir) if File.directory?(@temp_dir)
  end

  shared_examples_for "included correctly" do

    it "copies reuslt files into the run directory" do
      include_job
      @run.dir.join("_stdout.txt").should be_exist
    end

    it "parses _status.json" do
      include_job
      @run.hostname.should eq "hostXXX"
      @run.started_at.should be_a(DateTime)
      @run.finished_at.should be_a(DateTime)
      @run.status.should eq :finished
    end

    it "parses _time.txt" do
      include_job
      @run.cpu_time.should be_within(0.01).of(8.0)
      @run.real_time.should be_within(0.01).of(10.0)
    end

    it "deletes archive file after the inclusion finishes" do
      include_job
      @archive_full_path.should_not be_exist
    end

    it "invokes create_auto_run_analyses" do
      JobIncluder.should_receive(:create_auto_run_analyses)
      include_job
    end
  end

  describe "manual job" do

    before(:each) do
      @run = @sim.parameter_sets.first.runs.create(submitted_to: nil)
      ResultDirectory.manual_submission_job_script_path(@run).should be_exist
      make_valid_archive_file(@run)
    end

    let(:include_job) { JobIncluder.include_manual_job(@archive_full_path, @run) }

    it_behaves_like "included correctly"

    it "deletes job script after inclusion" do
      ResultDirectory.manual_submission_job_script_path(@run).should_not be_exist
    end
  end

  describe "remote job" do

    before(:each) do
      @host = @sim.executable_on.where(name: "localhost").first
      @host.work_base_dir = @temp_dir.expand_path
      @host.save!
      @run = @sim.parameter_sets.first.runs.create(submitted_to: @host)
    end

    describe "correct case" do

      before(:each) do
        make_valid_archive_file(@run)
      end

      let(:include_job) { JobIncluder.include_remote_job(@host, @run) }

      it_behaves_like "included correctly"
    end

    describe "when work_dir exists" do

      before(:each) do
        make_valid_archive_file(@run, true)
        JobIncluder.include_remote_job(@host, @run)
        @run.reload
      end

      it "updates status to failed" do
        @run.status.should eq :failed
      end

      it "copies files in work_dir" do
        @run.dir.join("_stdout.txt").should be_exist
      end

      it "deletes remote work_dir and archive file" do
        Dir.entries(@temp_dir).should eq ['.', '..']
      end
    end
  end
end
