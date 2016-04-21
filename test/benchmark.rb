#require File.join(Rails.root, 'spec_helper')
require 'spec_helper'
require File.join(Rails.root, 'lib/cli/oacis_cli')
require 'benchmark'

describe OacisCli do

  describe "#create_parameter_sets" do

    before(:each) do
      @sim = FactoryGirl.create(:simulator, parameter_sets_count: 0)
    end

    def create_simulator_id_json(simulator, path)
      File.open(path, 'w') {|io|
        io.puts( {"simulator_id" => simulator.id.to_s}.to_json )
        io.flush
      }
    end

    # create 10000 parameter_sets
    it 'takes time' do
      at_temp_dir {
        create_simulator_id_json(@sim, 'simulator_id.json')
        File.open('parameter_sets.json', 'w') {|io|
          parameters = []
          100.times do |i|
            100.times do |j|
              parameters << {"L" => i, "T" => j.to_f}
            end
          end
          io.puts parameters.to_json
        }
        option = {simulator: 'simulator_id.json', input: 'parameter_sets.json', output: "parameter_set_ids.json", yes: true}
        expect(Benchmark.realtime{
          OacisCli.new.invoke(:create_parameter_sets, [], option)
        }).to be < 60.0 # acctual results were 44.51, 43.56, 48.52, 44.87
      }
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

    # create 2000 runs ( 1000 runs for a parameter_set )
    it 'takes time' do
      at_temp_dir {
        create_parameter_set_ids_json(@sim.parameter_sets, 'parameter_set_ids.json')
        create_job_parameters_json('job_parameters.json')
        options = {
          parameter_sets: 'parameter_set_ids.json',
          job_parameters: 'job_parameters.json',
          number_of_runs: 1000,
          output: 'run_ids.json'
        }
        expect(Benchmark.realtime{
          OacisCli.new.invoke(:create_runs, [], options)
        }).to be < 60.0 # acctual results were 45.01, 45.50, 45.59, 51.08
      }
    end
  end

  describe "#create_analyses" do

    before(:each) do
      @host = FactoryGirl.create(:host_with_parameters)
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

    context "with type on_run" do

      before(:each) do
        @sim = FactoryGirl.create(:simulator, parameter_sets_count: 2, runs_count: 0,
                                  finished_runs_count: 1000,
                                  analyzers_count: 1, run_analysis: false,
                                  analyzers_on_parameter_set_count: 1,
                                  run_analysis_on_parameter_set: false)
        @sim.analyzers.each do |azr|
          azr.update_attribute(:support_mpi, true)
          azr.update_attribute(:support_omp, true)
        end
      end

      #create 2000 analyses with type on_run
      it 'takes time' do
        at_temp_dir {
          analyzer_id = @sim.analyzers.where(type: :on_run).first.id.to_s
          create_job_parameters_json('job_parameters.json')
          options = { analyzer_id: analyzer_id, input: 'azr_parameters.json',
                      output: 'analysis_ids.json', job_parameters: 'job_parameters.json'}
          OacisCli.new.invoke(:analyses_template, [], {analyzer_id: analyzer_id, output: "azr_parameters.json"})
          expect(Benchmark.realtime{
            OacisCli.new.invoke(:create_analyses, [], options)
          }).to be < 60.0 # acctual results were 26.21, 24.66, 25.74, 25.87
        }
      end
    end

    context "with type on_parameter_set" do
      before(:each) do
        @sim = FactoryGirl.create(:simulator, parameter_sets_count: 2000, runs_count: 0,
                                  finished_runs_count: 2,
                                  analyzers_count: 1, run_analysis: false,
                                  analyzers_on_parameter_set_count: 1,
                                  run_analysis_on_parameter_set: false)
        @sim.analyzers.each do |azr|
          azr.update_attribute(:support_mpi, true)
          azr.update_attribute(:support_omp, true)
        end
      end

      #create 2000 analyses with type on_parameter_set
      it 'takes time' do
        at_temp_dir {
          analyzer_id = @sim.analyzers.where(type: :on_parameter_set).first.id.to_s
          create_job_parameters_json('job_parameters.json')
          options = { analyzer_id: analyzer_id, input: 'azr_parameters.json',
                      output: 'analysis_ids.json', job_parameters: 'job_parameters.json'}
          OacisCli.new.invoke(:analyses_template, [], {analyzer_id: analyzer_id, output: "azr_parameters.json"})
          expect(Benchmark.realtime{
            OacisCli.new.invoke(:create_analyses, [], options)
          }).to be < 60.0 # acctual results were 35.46, 32.02, 32.37, 39.50
        }
      end
    end
  end
end

