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
  end

  factory :parameter do
    # IMPLEMENT ME
  end
end
