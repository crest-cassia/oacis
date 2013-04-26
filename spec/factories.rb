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
      analyzer_count 2
    end
    after(:create) do |simulator, evaluator|
      FactoryGirl.create_list(:parameter_set, evaluator.parameter_sets_count,
                                simulator: simulator, runs_count: evaluator.runs_count)
      FactoryGirl.create_list(:analyzer, evaluator.analyzer_count,
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
            {"type"=>"Integer", "default" => 0, "description" => "Initial"},
          "param2" =>
            {"type"=>"Float", "default" => 1.0, "description" => "Temperature"}
        }
    parameter_definitions h
    description { Faker::Lorem.paragraphs.join("\n") }
  end
end
