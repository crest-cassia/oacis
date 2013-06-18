require 'spec_helper'

describe DataIncluder do
  
  before(:each) do
    @sim = FactoryGirl.create(:simulator,
                              parameter_sets_count: 1, runs_count: 1, parameter_set_queries_count:1)
    @prm = @sim.parameter_sets.first
    @run = @prm.runs.first

    @localhost = FactoryGirl.create(:localhost)

    @temp_dir = Pathname.new('__temp')
    FileUtils.mkdir_p(@temp_dir)
  end

  after(:each) do
    FileUtils.rm_r(@temp_dir) if File.directory?(@temp_dir)
  end

  describe ".perform" do

    shared_examples_for 'for successful run' do

      before(:each) do
        ENV['CM_WORK_DIR'] = @temp_dir.expand_path.to_s
        run_info = {"id" => @run.id, "command" => @run.command}
        SimulatorRunner.perform(run_info)
        @work_dir = Pathname.new(ENV['CM_WORK_DIR']).join(@run.id)
      end

      it "copies all the files in the work dir to run_directory" do
        Host.any_instance.should_receive(:download).and_call_original if @is_remote
        dummy_dir = @work_dir.join('__dummy_dir__')
        FileUtils.mkdir_p(dummy_dir)
        DataIncluder.perform(@arg)
        File.exist?(@run.dir.join('_stdout.txt')).should be_true
        File.exist?(@run.dir.join('_stderr.txt')).should be_true
        File.directory?(@run.dir.join('__dummy_dir__')).should be_true
      end

      it "does not copy '_input.json' and '_output.json'" do
        filenames = ['_input.json', '_output.json']
        filenames.each do |f|
          FileUtils.touch( @work_dir.join(f) )
        end

        DataIncluder.perform(@arg)
        filenames.each do |f|
          File.exist?( @run.dir.join(f) ).should be_false
        end
      end

      it "updates attributes of Run" do
        DataIncluder.perform(@arg)
        @run.reload
        @run.status.should eq(:finished)
        @run.hostname.should_not be_nil
        @run.hostname.should eq @arg["run_status"]["hostname"]
        @run.cpu_time.should eq @arg["run_status"]["cpu_time"]
        @run.real_time.should eq @arg["run_status"]["real_time"]
        @run.started_at.should be_a(DateTime)
        @run.finished_at.should be_a(DateTime)
        @run.included_at.should be_a(DateTime)
      end

      it "removes working directory after copy has successfully finished" do
        Host.any_instance.should_receive(:rm_r).and_call_original if @is_remote
        DataIncluder.perform(@arg)
        File.directory?(@work_dir).should be_false
      end

      it "stores contents of '_output.json' into Run#result" do
        File.open(@work_dir.join('_output.json'), 'w') do |io|
          io.print ({x: 1.0, y: 2.0}).to_json
        end

        DataIncluder.perform(@arg)
        @run.reload
        @run.result.should be_a(Hash)
        @run.result["x"].should eq(1.0)
        @run.result["y"].should eq(2.0)
      end

      describe "auto run of analyzers for on_run type" do

        before(:each) do
          @azr = FactoryGirl.create(:analyzer, simulator: @sim, type: :on_run, auto_run: :yes)
        end

        context "when Analyzer#auto_run is :yes" do

          it "creates analysis_run if Analyzer#auto_run is :yes" do
            expect {
              DataIncluder.perform(@arg)
            }.to change { @run.reload.analysis_runs.count }.by(1)
          end
        end

        context "when Analyzer#auto_run is :no" do

          it "does not create analysis_run if Anaylzer#auto_run is :no" do
            @azr.update_attributes!(auto_run: :no)

            expect {
              DataIncluder.perform(@arg)
            }.to_not change { @run.reload.analysis_runs.count }
          end
        end

        context "when Analyzer#auto_run is :first_run_only" do

          before(:each) do
            @azr.update_attributes!(auto_run: :first_run_only)
          end

          it "creates analysis_run if the run is the first 'finished' run within the parameter set" do
            expect {
              DataIncluder.perform(@arg)
            }.to change { @run.reload.analysis_runs.count }.by(1)
          end

          it "does not create analysis if 'finished' run already exists within the paramter set" do
            FactoryGirl.create(:run, parameter_set: @prm, status: :finished)
            expect {
              DataIncluder.perform(@arg)
            }.to_not change { @run.reload.analysis_runs.count }
          end
        end
      end

      describe "auto run of analyzers for on_parameter_set type" do

        before(:each) do
          @azr = FactoryGirl.create(:analyzer, simulator: @sim, type: :on_parameter_set, auto_run: :yes)
        end

        it "creates analysis run if all the other runs within the parameter set are 'finished' or 'failed'" do
          FactoryGirl.create(:run, parameter_set: @prm, status: :failed)
          FactoryGirl.create(:run, parameter_set: @prm, status: :finished)
          expect {
            DataIncluder.perform(@arg)
          }.to change { @prm.reload.analysis_runs.count }
        end

        it "does not create analysis run if any of runs within the parameter set is 'created' or 'running'" do
          FactoryGirl.create(:run, parameter_set: @prm, status: :create)
          expect {
            DataIncluder.perform(@arg)
          }.to_not change { @prm.reload.analysis_runs.count }
        end
      end
    end

    context "for a successful remote run" do

      it_should_behave_like 'for successful run' do

        before(:each) do
          @arg = { "run_id" => @run.id, "work_dir" => @work_dir.to_s,
                   "host_id" => @localhost.id.to_s,
                   "run_status" => {
                     "hostname" => `hostname`,
                     "started_at" => DateTime.now.to_s,
                     "status" => "finished",
                     "rc" => 0,
                     "cpu_time" => 3.0,
                     "real_time" => 4.0,
                     "finished_at" => DateTime.now.to_s
                   }
                 }
          @is_remote = true
        end
      end
    end

    context "for a successful local run" do

      it_should_behave_like 'for successful run' do

        before(:each) do
          @arg = { "run_id" => @run.id, "work_dir" => @work_dir.to_s,
                   "run_status" => {
                     "hostname" => `hostname`,
                     "started_at" => DateTime.now.to_s,
                     "status" => "finished",
                     "rc" => 0,
                     "cpu_time" => 3.0,
                     "real_time" => 4.0,
                     "finished_at" => DateTime.now.to_s
                   }
                 }
          @is_remote = false
        end
      end
    end

    context "for a failed run" do

      before(:each) do
        ENV['CM_WORK_DIR'] = @temp_dir.expand_path.to_s

        run_info = {"id" => @run.id, "command" => "INVALID_CMD"}
        SimulatorRunner.perform(run_info)

        @work_dir = Pathname.new(ENV['CM_WORK_DIR']).join(@run.id)
        @arg = { "run_id" => @run.id, "work_dir" => @work_dir.to_s,
                 "host_id" => @localhost.id.to_s,
                 "run_status" => {
                   "hostname" => `hostname`,
                   "started_at" => DateTime.now.to_s,
                   "status" => "failed",
                   "rc" => 0,
                   "cpu_time" => 3.0,
                   "real_time" => 4.0,
                   "finished_at" => DateTime.now.to_s
                 }
               }
      end

      it "updates attributes of Run" do
        DataIncluder.perform(@arg)
        @run.reload
        @run.status.should eq(:failed)
        @run.hostname.should eq @arg["run_status"]["hostname"]
        @run.cpu_time.should eq @arg["run_status"]["cpu_time"]
        @run.real_time.should eq @arg["run_status"]["real_time"]
        @run.started_at.should be_a(DateTime)
        @run.finished_at.should be_a(DateTime)
        @run.included_at.should be_a(DateTime)
      end

      it "does not run analyzer even if Analyzer#auto_run is :yes" do
        azr = @sim.analyzers.first
        azr.update_attributes!(auto_run: :yes)

        expect {
          DataIncluder.perform(@arg)
        }.to_not change {@run.reload.analysis_runs.count }
      end
    end

    context "when file copy fails" do

      it "does not remove working directory"

      it "updates status of Run to failed"
    end
  end
end