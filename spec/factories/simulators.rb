# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :simulator do
    name "MyString"
    execution_command "MyString"
    parameter_keys {"L"=>{"type"=>"Integer"},"T"=>{"type"=>"Float"}}
    # analysis_methods "MyString"
    # simulator_admin_users "MyString"
    # editable_users "MyString"
    # readable_users "MyString"
    # comments "MyString"
  end
end
