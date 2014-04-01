# Read about factories at https://github.com/thoughtbot/factory_girl
require 'faker'

FactoryGirl.define do

  factory :simulator do
    sequence(:name, 'A') {|n| "simulator#{n}"}
    command "echo"
    print_version_command "echo \"v1.0.0\""

    parameter_definitions {
      [
      ParameterDefinition.new(
        { key: "L", type: "Integer", default: 50, description: "System size"}),
      ParameterDefinition.new(
        { key: "T", type: "Float", default: 1.0, description: "Temperature" })
      ]
    }
    description { Faker::Lorem.paragraphs.join("\n") }

    ignore do
      parameter_sets_count 5
      runs_count 5
      finished_runs_count 0
      analyzers_count 2
      run_analysis true
      analyzers_on_parameter_set_count 0
      run_analysis_on_parameter_set true
      parameter_set_queries_count 0
    end

    after(:create) do |simulator, evaluator|
      if Host.where(name: "localhost").present?
        h = Host.where(name: "localhost").first
        h.executable_simulators.push simulator
        h.save!
      else
        h = FactoryGirl.create(:localhost, executable_simulators: [simulator])
      end
      FactoryGirl.create_list(:parameter_set, evaluator.parameter_sets_count,
                              simulator: simulator,
                              runs_count: evaluator.runs_count,
                              finished_runs_count: evaluator.finished_runs_count
                              )
      FactoryGirl.create_list(:analyzer, evaluator.analyzers_count,
                              simulator: simulator,
                              run_analysis: evaluator.run_analysis
                              )
      FactoryGirl.create_list(:analyzer, evaluator.analyzers_on_parameter_set_count,
                              simulator: simulator,
                              type: :on_parameter_set,
                              run_analysis: evaluator.run_analysis_on_parameter_set
                              )
      FactoryGirl.create_list(:parameter_set_query, evaluator.parameter_set_queries_count,
                              simulator: simulator
                              )
    end
  end

  factory :parameter_set do
    sequence(:v) do |n|
      {"L" => n, "T" => n*2.0}
    end

    ignore do
      runs_count 5
      finished_runs_count 0
    end

    after(:create) do |param_set, evaluator|
      FactoryGirl.create_list(:run, evaluator.runs_count, parameter_set: param_set)
      FactoryGirl.create_list(:finished_run, evaluator.finished_runs_count, parameter_set: param_set)
    end
  end

  factory :run do

    submitted_to { self.parameter_set.simulator.executable_on.where(name: "localhost").first }

    factory :finished_run do

      after(:create) do |run, evaluator|
        run.hostname = 'hostXYZ'
        run.cpu_time = rand * 100.0
        run.real_time = run.cpu_time + rand * 2.0
        run.result = {"Energy" => rand*1.0, "Flow" => rand*3.0}
        d = DateTime.now
        run.finished_at = d
        run.included_at = d
        run.status = :finished
        run.save!
      end
    end
  end

  factory :analyzer do
    sequence(:name, 'A') {|n| "analyzer_#{n}"}
    type { :on_run }
    command { "cat _input.json" }
    parameter_definitions {
      [
      ParameterDefinition.new(
        { key: "param1", type: "Integer", default: 50, description: "param1 desc"}),
      ParameterDefinition.new(
        { key: "param2", type: "Float", default: 1.0, description: "param2 desc" })
      ]
    }
    description { Faker::Lorem.paragraphs.join("\n") }

    ignore do
      run_analysis true
    end

    after(:create) do |analyzer, evaluator|
      if evaluator.run_analysis
        case analyzer.type
        when :on_run
          analyzer.simulator.parameter_sets.each do |ps|
            ps.runs.each do |run|
              FactoryGirl.create(:analysis, analyzable: run, analyzer: analyzer, parameters: {})
            end
          end
        when :on_parameter_set
          analyzer.simulator.parameter_sets.each do |ps|
            FactoryGirl.create(:analysis, analyzable: ps, analyzer: analyzer, parameters: {})
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
    sequence(:result) do |n|
      {"XXX" => n + 1, "YYY" => n*3.0}
    end
  end

  factory :parameter_set_query do
    sequence(:query) do |n|
      {"T" => {"gte" => n*2.0}, "L"=> {"lte" => n}}
    end
  end

  factory :host do
    sequence(:name, 'A') {|n| "Host_#{n}"}
    sequence(:hostname, 'A') {|n| "hostname.#{n}"}
    min_mpi_procs 1
    max_mpi_procs 8
    min_omp_threads 1
    max_omp_threads 8
    user "login_user"

    factory :host_with_parameters do
      new_header = <<-EOS
#!/bin/bash
# param1:<%= param1 %>
# param2:<%= param2 %>
EOS
      template { JobScriptUtil::DEFAULT_TEMPLATE.sub("#!/bin/bash", new_header) }
      host_parameter_definitions {
        [
          HostParameterDefinition.new(key: "param1"),
          HostParameterDefinition.new(key: "param2", default: "XXX")
        ]
      }
    end
  end

  factory :localhost, class: Host do
    name "localhost"
    hostname { `hostname`.chomp }
    min_mpi_procs 1
    max_mpi_procs 8
    min_omp_threads 1
    max_omp_threads 8
    user {ENV['USER']}
  end
end
