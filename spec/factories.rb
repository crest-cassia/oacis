# Read about factories at https://github.com/thoughtbot/factory_girl
require 'faker'

FactoryGirl.define do
  factory :user do
    name 'Test User'
    email 'example@example.com'
    password 'please'
    password_confirmation 'please'
    # required if the Devise Confirmable module is used
    # confirmed_at Time.now
  end

  factory :simulator do
    sequence(:name, 'A') {|n| "simulator#{n}"}
    command { Rails.root.join('spec','support','echo.sh') } #"~/path/to/#{name}"}
    h = { "L"=>{"type"=>"Integer", "default" => 50, "description" => "System size"},
          "T"=>{"type"=>"Float", "default" => 1.0, "description" => "Temperature"}
        }
    parameter_definitions h
    description { Faker::Lorem.paragraphs.join("\n") }

    ignore do
      parameter_sets_count 5
      runs_count 5
      finished_runs_count 0
      analyzers_count 2
      run_analysis true
      analyzers_on_parameter_set_count 0
      run_analysis_on_parameter_set true
    end
    after(:create) do |simulator, evaluator|
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

    factory :finished_run do

      after(:create) do |run, evaluator|
        run.set_status_running(hostname: 'hostXYZ')
        cpu_time = rand * 100.0
        real_time = cpu_time + rand * 2.0
        result_hash = {"Energy" => rand*1.0, "Flow" => rand*3.0}
        run.set_status_finished(cpu_time: cpu_time,
                                real_time: real_time,
                                result: result_hash
                                )
        FileUtils
      end
    end
  end

  factory :analyzer do
    sequence(:name, 'A') {|n| "analyzer_#{n}"}
    type { :on_run }
    command { "cat _input.json" }

    sequence(:parameter_definitions, 0) do |n|
      h = {}
      types = ["Integer","Float","String","Boolean"]
      defaults = [1, 2.0, "abc", true]
      types.size.times do |i|
        next if n == i
        h["param#{i}"] = {"type" => types[i], "default" => defaults[i], "description" => "description for param#{i}"}
      end
      h
    end
    # parameter_definitions h
    description { Faker::Lorem.paragraphs.join("\n") }

    ignore do
      run_analysis true
    end

    after(:create) do |analyzer, evaluator|
      if evaluator.run_analysis
        sim = analyzer.simulator.parameter_sets.each do |ps|
          case analyzer.type
          when :on_parameter_set
            FactoryGirl.create(:analysis_run, analyzable: ps, analyzer: analyzer, parameters: {})
          when :on_run
            ps.runs.each do |run|
              FactoryGirl.create(:analysis_run, analyzable: run, analyzer: analyzer, parameters: {})
            end
          else
            raise "not supported type"
          end
        end
      end
    end
  end

  factory :analysis_run do
    h = {"param1" => 1, "param2" => 2.0}
    parameters h
  end
end
