require 'spec_helper'
require File.join(Rails.root, 'lib/cli/oacis_cli')

describe OacisCli do

  describe "#job_parameter_template" do

    before(:each) do
      @host = FactoryGirl.create(:host_with_parameters)
    end

    it "outputs a template of job_parameters" do
      at_temp_dir {
        options = { host_id: @host.id.to_s, output: 'job_parameters.json'}
        OacisCli.new.invoke(:job_parameter_template, [], options)
        expect(File.exist?('job_parameters.json')).to be_truthy
        expect {
          JSON.load(File.read('job_parameters.json'))
        }.not_to raise_error
      }
    end

    it "outputs a template having default job_parameters" do
      at_temp_dir {
        options = { host_id: @host.id.to_s, output: 'job_parameters.json'}
        OacisCli.new.invoke(:job_parameter_template, [], options)

        expected = {
          "host_id" => @host.id.to_s,
          "host_parameters" => {"param1" => nil, "param2" => "XXX"},
          "mpi_procs" => 1,
          "omp_threads" => 1,
          "priority" => 1
        }
        expect(JSON.load(File.read('job_parameters.json'))).to eq expected
      }
    end

    context "when host id is invalid" do

      it "raises an exception" do
        at_temp_dir {
          options = { host_id: "DO_NOT_EXIST", output: 'job_parameters.json'}
          expect {
            OacisCli.new.invoke(:job_parameter_template, [], options)
          }.to raise_error
        }
      end
    end

    context "when dry_run option is specified" do

      it "does not create output file" do
        at_temp_dir {
          options = {
            host_id: @host.id.to_s,
            output: 'job_parameters.json',
            dry_run: true
          }
          OacisCli.new.invoke(:job_parameter_template, [], options)
          expect(File.exist?('job_parameters.json')).to be_falsey
        }
      end
    end

    context "when output file exists" do

      it "asks a question to overwrite the output file" do
        at_temp_dir {
          FileUtils.touch("job_parameters.json")
          expect(Thor::LineEditor).to receive(:readline).with("Overwrite output file? ", :add_to_history => false).and_return("y")
          options = { host_id: @host.id.to_s, output: 'job_parameters.json'}
          OacisCli.new.invoke(:job_parameter_template, [], options)
        }
      end
    end

    context "with yes option when output file exists" do

      it "does not ask a question to overwrite the output file" do
        at_temp_dir {
          FileUtils.touch("job_parameters.json")
          expect(Thor::LineEditor).not_to receive(:readline).with("Overwrite output file? ", :add_to_history => false)
          options = { host_id: @host.id.to_s, output: 'job_parameters.json', yes: true}
          OacisCli.new.invoke(:job_parameter_template, [], options)
          expect(File.exist?('job_parameters.json')).to be_truthy
          expect {
            JSON.load(File.read('job_parameters.json'))
          }.not_to raise_error
        }
      end
    end
  end

  describe "#create_runs" do

    before(:each) do
      @host = FactoryGirl.create(:host_with_parameters)
      @sim = FactoryGirl.create(:simulator,
                                parameter_sets_count: 2, runs_count: 0,
                                support_mpi: true, support_omp: true)
      @sim.executable_on.push @host
    end

    def create_parameter_set_ids_json(parameter_sets, path)
      File.open(path, 'w') {|io|
        ids = parameter_sets.map {|ps| {"parameter_set_id" => ps.id.to_s} }
        io.puts ids.to_json
        io.flush
      }
    end

    def create_job_parameters_json(path)
      File.open(path, 'w') {|io|
        job_parameters = {
          "host_id" => @host.id.to_s,
          "host_parameters" => {"param1" => "foo", "param2" => "bar"},
          "mpi_procs" => 2,
          "omp_threads" => 8,
          "priority" => 0
        }
        io.puts job_parameters.to_json
        io.flush
      }
    end

    def invoke_create_runs
      create_parameter_set_ids_json(@sim.parameter_sets, 'parameter_set_ids.json')
      create_job_parameters_json('job_parameters.json')
      options = {
        parameter_sets: 'parameter_set_ids.json',
        job_parameters: 'job_parameters.json',
        number_of_runs: 3,
        output: 'run_ids.json'
      }
      OacisCli.new.invoke(:create_runs, [], options)
    end

    it "creates runs for each parameter_set" do
      at_temp_dir {
        expect {
          invoke_create_runs
        }.to change { Run.count }.by(6)
      }
    end

    it "creates run having correct attributes" do
      at_temp_dir {
        invoke_create_runs
        run = @sim.parameter_sets.first.runs.first
        expect(run.submitted_to).to eq @host
        expect(run.mpi_procs).to eq 2
        expect(run.omp_threads).to eq 8
        expect(run.priority).to eq 0
        expect(run.host_parameters).to eq({"param1" => "foo", "param2" => "bar"})
      }
    end

    it "outputs ids of created runs in json" do
      at_temp_dir {
        invoke_create_runs

        expect(File.exist?('run_ids.json')).to be_truthy
        expected = Run.all.map {|run| {"run_id" => run.id.to_s} }.sort_by {|h| h["run_id"]}
        expect(JSON.load(File.read('run_ids.json'))).to match_array(expected)
      }
    end

    context "when run exists" do

      before(:each) do
        @ps1 = @sim.parameter_sets.first
        FactoryGirl.create_list(:run, 5, parameter_set: @ps1, submitted_to: @host,
                                host_parameters: {"param1" => "XXX", "param2" => "YYY"}
                                )
        @ps2 = @sim.parameter_sets[1]
        FactoryGirl.create_list(:run, 1, parameter_set: @ps2, submitted_to: @host,
                                host_parameters: {"param1" => "XXX", "param2" => "YYY"}
                                )
      end

      it "iterates creation of runs up to the specified number" do
        at_temp_dir {
          expect {
            invoke_create_runs
          }.to change { Run.count }.by(2)
        }
      end

      it "outputs ids of created and existing runs up to the specified number" do
        at_temp_dir {
          invoke_create_runs

          expect(File.exist?('run_ids.json')).to be_truthy
          runs = @ps1.reload.runs.limit(3).to_a + @ps2.reload.runs.limit(3)
          expected = runs.map {|run| {"run_id" => run.id.to_s} }.sort_by {|h| h["run_id"]}
          expect(JSON.load(File.read('run_ids.json'))).to match_array(expected)
        }
      end
    end

    context "when job_parameters are invalid" do

      def create_invalid_job_parameters_json(path)
        File.open(path, 'w') {|io|
          job_parameters = {
            "host_id" => @host.id.to_s,
            "host_parameters" => {"param1" => "foo"}, # Do not set param2
            "mpi_procs" => 2,
            "omp_threads" => 8,
            "priority" => 0
          }
          io.puts job_parameters.to_json
          io.flush
        }
      end

      it "raises an exception" do
        at_temp_dir {
          create_parameter_set_ids_json(@sim.parameter_sets, 'parameter_set_ids.json')
          create_invalid_job_parameters_json('job_parameters.json')
          options = {
            parameter_sets: 'parameter_set_ids.json',
            job_parameters: 'job_parameters.json',
            number_of_runs: 3,
            output: 'run_ids.json'
          }
          expect {
            OacisCli.new.invoke(:create_runs, [], options)
          }.to raise_error
        }
      end
    end

    context "when parameter_set_ids.json is invalid" do

      def create_invalid_parameter_set_ids_json(parameter_sets, path)
        File.open(path, 'w') {|io|
          ids = parameter_sets.map {|ps| {"parameter_set_id" => ps.id.to_s} }
          ids.push( {"parameter_set_id" => "DO_NOT_EXIST"} )
          io.puts ids.to_json
          io.flush
        }
      end

      def invoke_create_runs_with_invalid_parameter_set_ids
        create_invalid_parameter_set_ids_json(@sim.parameter_sets, 'parameter_set_ids.json')
        create_job_parameters_json('job_parameters.json')
        options = {
          parameter_sets: 'parameter_set_ids.json',
          job_parameters: 'job_parameters.json',
          number_of_runs: 3,
          output: 'run_ids.json'
        }
        OacisCli.new.invoke(:create_runs, [], options)
      end

      it "raises an exception" do
        at_temp_dir {
          expect {
            invoke_create_runs_with_invalid_parameter_set_ids
          }.to raise_error
        }
      end

      it "outputs run_ids if successfully created runs exist" do
        at_temp_dir {
          begin
            invoke_create_runs_with_invalid_parameter_set_ids
          rescue
          end
          expect(File.exist?('parameter_set_ids.json')).to be_truthy
        }
      end

    end

    context "when dry_run option is given" do

      def invoke_create_runs_with_dry_run
        create_parameter_set_ids_json(@sim.parameter_sets, 'parameter_set_ids.json')
        create_job_parameters_json('job_parameters.json')
        options = {
          parameter_sets: 'parameter_set_ids.json',
          job_parameters: 'job_parameters.json',
          number_of_runs: 3,
          output: 'run_ids.json',
          dry_run: true
        }
        OacisCli.new.invoke(:create_runs, [], options)
      end

      it "does not save Runs" do
        at_temp_dir {
          expect {
            invoke_create_runs_with_dry_run
          }.to_not change { Run.count }
        }
      end

      it "does not create output file" do
        at_temp_dir {
          invoke_create_runs_with_dry_run
          expect(File.exist?('run_ids.json')).to be_falsey
        }
      end
    end

    context "when output file exists" do

      it "asks a question to overwrite the output file" do
        at_temp_dir {
          FileUtils.touch("run_ids.json")
          expect(Thor::LineEditor).to receive(:readline).with("Overwrite output file? ", :add_to_history => false).and_return("y")
          options = { host_id: @host.id.to_s, output: 'job_parameters.json'}
          create_parameter_set_ids_json(@sim.parameter_sets, 'parameter_set_ids.json')
          create_job_parameters_json('job_parameters.json')
          options = {
            parameter_sets: 'parameter_set_ids.json',
            job_parameters: 'job_parameters.json',
            number_of_runs: 3,
            output: 'run_ids.json'
          }
          OacisCli.new.invoke(:create_runs, [], options)
        }
      end
    end

    context "with yes option when output file exists" do

      it "does not ask a question to overwrite the output file" do
        at_temp_dir {
          FileUtils.touch("run_ids.json")
          expect(Thor::LineEditor).not_to receive(:readline).with("Overwrite output file? ", :add_to_history => false)
          options = { host_id: @host.id.to_s, output: 'job_parameters.json'}
          create_parameter_set_ids_json(@sim.parameter_sets, 'parameter_set_ids.json')
          create_job_parameters_json('job_parameters.json')
          options = {
            parameter_sets: 'parameter_set_ids.json',
            job_parameters: 'job_parameters.json',
            number_of_runs: 3,
            output: 'run_ids.json',
            yes: true
          }
          OacisCli.new.invoke(:create_runs, [], options)
          expect(File.exist?('run_ids.json')).to be_truthy
          expect {
            JSON.load(File.read('run_ids.json'))
          }.not_to raise_error
        }
      end
    end
  end

  describe "#run_status" do

    before(:each) do
      @sim = FactoryGirl.create(:simulator, parameter_sets_count: 2, runs_count: 3)
    end

    def create_run_ids_json(runs, path)
      File.open(path, 'w') do |io|
        run_ids = runs.map {|run| {"run_id" => run.id.to_s} }
        io.puts run_ids.to_json
        io.flush
      end
    end

    it "shows number of runs for each status in json" do
      at_temp_dir {
        create_run_ids_json(Run.all, 'run_ids.json')
        options = {run_ids: 'run_ids.json'}
        expect {
          OacisCli.new.invoke(:run_status, [], options)
        }.to output(puts JSON.pretty_generate({total: 6, created: 6, running: 0, failed: 0, finished: 0})).to_stdout
      }
    end
  end

  describe "#destroy_runs" do

    before(:each) do
      @sim = FactoryGirl.create(:simulator,
                                parameter_sets_count: 1, runs_count: 0)
      ps = @sim.parameter_sets.first
      FactoryGirl.create(:run, parameter_set: ps).update_attribute(:simulator_version, "1.0.0")
      FactoryGirl.create(:run, parameter_set: ps).update_attribute(:simulator_version, "1.0.1")
      FactoryGirl.create(:finished_run, parameter_set: ps).update_attribute(:simulator_version, nil)
      @failed_run = FactoryGirl.create(:finished_run, parameter_set: ps)
        .tap {|r| r.update_attribute(:status, :failed) }
        .tap {|r| r.update_attribute(:simulator_version, nil) }

    end

    it "destroys runs specified by 'status'" do
      at_temp_dir {
        options = {simulator: @sim.id.to_s, query: {"status" => "failed"}, yes: true}
        expect {
          OacisCli.new.invoke(:destroy_runs, [], options)
        }.to change { Run.where(status: :failed).count }.by(-1)
      }
    end

    it "destroys runs specified by 'simulator_version'" do
      at_temp_dir {
        options = {simulator: @sim.id.to_s, query: {"simulator_version" => "1.0.0"}, yes: true}
        expect {
          OacisCli.new.invoke(:destroy_runs, [], options)
        }.to change { Run.where(simulator_version: "1.0.0").count }.by(-1)
      }
    end

    it "destroys runs of simulator_version=nil when simulator_version is empty" do
      at_temp_dir {
        options = {simulator: @sim.id.to_s, query: {"simulator_version" => ""}, yes: true}
        expect {
          OacisCli.new.invoke(:destroy_runs, [], options)
        }.to change { Run.where(simulator_version: nil).count }.by(-2)
      }
    end

    it "fails neither 'status' nor 'simulator_version' is given as the query-key" do
      at_temp_dir {
        options = {simulator: @sim.id.to_s, query: {"hostname" => "localhost"}, yes: true}
        expect {
          $stdout = StringIO.new # set new string stream not to write Thor#say message on test result
          OacisCli.new.invoke(:destroy_runs, [], options)
          $stdout = STDOUT
        }.to raise_error
      }
    end

    context "if user say \"no\" not to destroy runs" do

      it "destroys nothing" do
        at_temp_dir {
          expect(Thor::LineEditor).to receive(:readline).with("Destroy 1 runs? ", :add_to_history => false).and_return("n")
          options = {simulator: @sim.id.to_s, query: {"status" => "failed"} }
          expect {
            OacisCli.new.invoke(:destroy_runs, [], options)
          }.not_to change { Run.where(status: :failed).count }
        }
      end
    end

    context "with yes option" do

      it "destroys runs without confirmation" do
        at_temp_dir {
          expect(Thor::LineEditor).not_to receive(:readline).with("Destroy 1 runs? ", :add_to_history => false)
          options = {simulator: @sim.id.to_s, query: {"status" => "failed"}, yes: true}
          expect {
            OacisCli.new.invoke(:destroy_runs, [], options)
          }.to change { Run.where(status: :failed).count }.by(-1)
        }
      end
    end
  end

  describe "#replace_runs" do

    before(:each) do
      @sim = FactoryGirl.create(:simulator,
                                parameter_sets_count: 1, runs_count: 0)
      ps = @sim.parameter_sets.first
      FactoryGirl.create(:finished_run, parameter_set: ps, mpi_procs: 8, priority: 0)
        .update_attribute(:simulator_version, "1.0.0")
      FactoryGirl.create(:finished_run, parameter_set: ps, mpi_procs: 4)
        .update_attribute(:simulator_version, "1.0.1")
    end

    it "newly create runs have the same attribute as old ones" do
      at_temp_dir {
        options = {simulator: @sim.id.to_s, query: {"simulator_version" => "1.0.0"}, yes: true}
        expect {
          OacisCli.new.invoke(:replace_runs, [], options)
        }.to change { Run.where(status: :created).count }.by(1)
        new_run = Run.where(status: :created).first
        expect(new_run.mpi_procs).to eq 8
        expect(new_run.priority).to eq 0
      }
    end

    it "destroys old run" do
      at_temp_dir {
        options = { simulator: @sim.id.to_s, query: {"simulator_version" => "1.0.0"}, yes: true}
        expect {
          OacisCli.new.invoke(:replace_runs, [], options)
        }.to change { Run.where(simulator_version: "1.0.0").count }.from(1).to(0)
      }
    end

    context "if user say \"no\" not to replace runs" do

      it "replaces nothing" do
        at_temp_dir {
          expect(Thor::LineEditor).to receive(:readline).with("Replace 1 runs with new ones? ", :add_to_history => false).and_return("n")
          options = {simulator: @sim.id.to_s, query: {"simulator_version" => "1.0.0"}}
          expect {
            OacisCli.new.invoke(:replace_runs, [], options)
          }.not_to change { Run.where(status: :created).count }
        }
      end
    end

    context "with yes option" do

      it "replaces runs without confirmation" do
        at_temp_dir {
          expect(Thor::LineEditor).not_to receive(:readline).with("Replace 1 runs with new ones? ", :add_to_history => false)
          options = {simulator: @sim.id.to_s, query: {"simulator_version" => "1.0.0"}, yes: true}
          expect {
            OacisCli.new.invoke(:replace_runs, [], options)
          }.to change { Run.where(status: :created).count }.by(1)
        }
      end
    end
  end
end

