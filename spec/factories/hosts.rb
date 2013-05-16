# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :host do
    name "MyString"
    hostname "MyString"
    user "MyString"
    port 1
    ssh_key "MyString"
    show_status_command "MyString"
    submission_command "MyString"
    work_base_dir "MyString"
    simulator_base_dir "MyString"
  end
end
