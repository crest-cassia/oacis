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
    execution_command { Rails.root.join('spec','support','echo.sh') } #"~/path/to/#{name}"}
    h = { "L"=>{"type"=>"Integer", "default" => 50, "description" => "System size"},
          "T"=>{"type"=>"Float", "default" => 1.0, "description" => "Temperature"}
        }
    parameter_definitions h
    description { Faker::Lorem.paragraphs.join("\n") }

    ignore do
      parameter_sets_count 5
      runs_count 5
      analyzers_count 2
      run_analysis true
    end
    after(:create) do |simulator, evaluator|
      FactoryGirl.create_list(:parameter_set, evaluator.parameter_sets_count,
                              simulator: simulator,
                              runs_count: evaluator.runs_count
                              )
      FactoryGirl.create_list(:analyzer, evaluator.analyzers_count,
                              simulator: simulator,
                              run_analysis: evaluator.run_analysis
                              )
    end
  end

  factory :parameter_set do
    sequence(:v) do |n|
      {"L" => n, "T" => n*2.0}
    end

    ignore do
      runs_count 5
    end

    after(:create) do |param_set, evaluator|
      FactoryGirl.create_list(:run, evaluator.runs_count, parameter_set: param_set)
    end
  end

  factory :run do
  end

  factory :analyzer do
    sequence(:name, 'A') {|n| "analyzer_#{n}"}
    type { :on_run }
    command { "/path/to/#{name}" }

    h = { "param1" =>
            {"type"=>"Integer", "default" => 0, "description" => "Initial step"},
          "param2" =>
            {"type"=>"Float", "default" => 1.0, "description" => "Temperature"}
        }
    parameter_definitions h
    description { Faker::Lorem.paragraphs.join("\n") }

    ignore do
      run_analysis true
    end

    after(:create) do |analyzer, evaluator|
      if evaluator.run_analysis
        sim = analyzer.simulator.parameter_sets.each do |ps|
          case analyzer.type
          when :on_parameter_set
            FactoryGirl.create(:analysis_run, analyzable: ps, analyzer: analyzer)
          when :on_run
            ps.runs.each do |run|
              FactoryGirl.create(:analysis_run, analyzable: run, analyzer: analyzer)
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
