# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :simulator do
    name "SimulatorA"
    execution_command "~/path/to/simulatorA"
    # parameter_keys {"L"=>{"type"=>"Integer"}, "T"=>{"type"=>"Float"}}
  end
end
