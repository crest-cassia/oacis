# Read about factories at https://github.com/thoughtbot/factory_bot
require 'faker'

FactoryBot.define do

  factory :simulator do
    sequence(:name, 'A') {|n| "simulator#{n}"}
    command "echo"

    parameter_definitions {
      [
      ParameterDefinition.new(
        { key: "L", type: "Integer", default: 50, description: "System size"}),
      ParameterDefinition.new(
        { key: "T", type: "Float", default: 1.0, description: "Temperature" })
      ]
    }
    description { Faker::Lorem.paragraphs.join("\n") }

    transient do
      parameter_sets_count 5
      runs_count 5
      finished_runs_count 0
      analyzers_count 2
      run_analysis true
      analyzers_on_parameter_set_count 0
      run_analysis_on_parameter_set true
      parameter_set_filters_count 0
      ssh_host false
    end

    after(:create) do |simulator, evaluator|
      if evaluator.ssh_host
        if Host.where(name: "localhost").present?
          h = Host.where(name: "localhost").first
          h.executable_simulators.push simulator
          h.save!
        else
          h = FactoryBot.create(:localhost, executable_simulators: [simulator])
        end
      else
        h = FactoryBot.create(:host, executable_simulators: [simulator])
      end
      simulator.save! # to update executable_on field
      FactoryBot.create_list(:parameter_set, evaluator.parameter_sets_count,
                              simulator: simulator,
                              runs_count: evaluator.runs_count,
                              finished_runs_count: evaluator.finished_runs_count
                              )
      FactoryBot.create_list(:analyzer, evaluator.analyzers_count,
                              simulator: simulator,
                              run_analysis: evaluator.run_analysis,
                              ssh_host: evaluator.ssh_host
                              )
      FactoryBot.create_list(:analyzer, evaluator.analyzers_on_parameter_set_count,
                              simulator: simulator,
                              type: :on_parameter_set,
                              run_analysis: evaluator.run_analysis_on_parameter_set,
                              ssh_host: evaluator.ssh_host
                              )
      FactoryBot.create_list(:parameter_set_filter, evaluator.parameter_set_filters_count,
                             simulator: simulator
                              )
    end
  end

  factory :parameter_set do
    sequence(:v) do |n|
      {"L" => n, "T" => n*2.0}
    end

    transient do
      runs_count 5
      finished_runs_count 0
    end

    after(:create) do |param_set, evaluator|
      FactoryBot.create_list(:run, evaluator.runs_count, parameter_set: param_set)
      FactoryBot.create_list(:finished_run, evaluator.finished_runs_count, parameter_set: param_set)
    end
  end

  factory :run do

    submitted_to {
      hosts = self.parameter_set.simulator.executable_on
      hosts.where(name: "localhost").first || hosts.first
    }

    factory :finished_run do

      after(:create) do |run, evaluator|
        run.hostname = 'hostXYZ'
        run.cpu_time = rand * 100.0
        run.real_time = run.cpu_time + rand * 2.0
        run.result = {"Energy" => rand*1.0, "Flow" => rand*3.0}
        d = DateTime.now
        run.started_at = d
        run.finished_at = d
        run.included_at = d
        run.status = :finished
        run.simulator_version = "v1"
        run.save!
      end
    end
  end

  factory :analyzer do
    sequence(:name, 'A') {|n| "analyzer_#{n}"}
    type { :on_run }
    command { "echo" }
    parameter_definitions {
      [
      ParameterDefinition.new(
        { key: "param1", type: "Integer", default: 50, description: "param1 desc"}),
      ParameterDefinition.new(
        { key: "param2", type: "Float", default: 1.0, description: "param2 desc" })
      ]
    }
    files_to_copy { '*' }
    description { Faker::Lorem.paragraphs.join("\n") }

    transient do
      run_analysis true
      ssh_host false
    end

    after(:create) do |analyzer, evaluator|
      if evaluator.ssh_host
        if Host.where(name: "localhost").present?
          h = Host.where(name: "localhost").first
          h.executable_analyzers.push analyzer
          h.save!
        else
          h = FactoryBot.create(:localhost, executable_analzyers: [analyzer])
        end
      else
        h = FactoryBot.create(:host, executable_analyzers: [analyzer])
      end
      analyzer.auto_run_submitted_to = analyzer.executable_on.first
      analyzer.save!
      if evaluator.run_analysis
        case analyzer.type
        when :on_run
          analyzer.simulator.parameter_sets.each do |ps|
            ps.runs.each do |run|
              FactoryBot.create(:analysis, analyzable: run, analyzer: analyzer, parameters: {})
            end
          end
        when :on_parameter_set
          analyzer.simulator.parameter_sets.each do |ps|
            FactoryBot.create(:analysis, analyzable: ps, analyzer: analyzer, parameters: {})
          end
        else
          raise "not supported type"
        end
      end
    end
  end

  factory :analysis do
    h = {"param1" => 1, "param2" => 2.0}
    parameters h
    status :finished
    submitted_to {
      hosts = self.analyzer.executable_on
      hosts.where(name: "localhost").first || hosts.first
    }
    sequence(:result) do |n|
      {"XXX" => n + 1, "YYY" => n*3.0}
    end
  end

  factory :parameter_set_filter do
    sequence(:name) {|n| "f_#{n}" }
    sequence(:conditions) do |n|
      [["T","gte",n*2.0], ["L","lte",n]]
    end
  end

  factory :host do
    before(:create) do |host|
      def host.get_host_parameters; []; end
    end
    sequence(:name, 'A') {|n| "Host_#{n}"}
    min_mpi_procs 1
    max_mpi_procs 8
    min_omp_threads 1
    max_omp_threads 8

    factory :host_with_parameters do
      host_parameter_definitions {
        [
          HostParameterDefinition.new(key: "param1"),
          HostParameterDefinition.new(key: "param2", default: "XXX")
        ]
      }
    end
  end

  factory :host_group do
    sequence(:name, 'A') {|n| "HostGroup_#{n}"}
    hosts {
      [ FactoryBot.create(:host) ]
    }
  end

  # :localhost needs ssh connection and xsub
  factory :localhost, class: Host do
    name "localhost"
    min_mpi_procs 1
    max_mpi_procs 8
    min_omp_threads 1
    max_omp_threads 8
  end
end
