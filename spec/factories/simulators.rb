# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :simulator do
    sequence(:name, 'AA') {|n| "simulator#{n}"}
    execution_command { "~/path/to/#{name}"}
    h = { "L"=>{"type"=>"Integer"}, "T"=>{"type"=>"Float"} }
    parameter_keys h
  end
end
