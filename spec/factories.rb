# Read about factories at https://github.com/thoughtbot/factory_girl

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
    execution_command { "~/path/to/#{name}"}
    h = { "L"=>{"type"=>"Integer"}, "T"=>{"type"=>"Float"} }
    parameter_keys h

    ignore do
      parameters_count 5
    end
    after(:create) do |simulator, evaluator|
      FactoryGirl.create_list(:parameter, evaluator.parameters_count, simulator: simulator)
    end
  end

  factory :parameter do
    sequence(:sim_parameters) do |n|
      {"L" => n, "T" => n*2.0}
    end
  end
end
