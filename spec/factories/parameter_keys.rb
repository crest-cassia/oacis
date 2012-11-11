# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :parameter_key do
    name "MyString"
    type ""
    default "MyString"
    restriction "MyString"
    description "MyString"
  end
end
