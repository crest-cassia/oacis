FactoryGirl.define do
  factory :host do
    sequence(:name, 'A') {|n| "Host_#{n}"}
    sequence(:hostname, 'A') {|n| "hostname.#{n}"}
    user "login_user"
  end

  factory :localhost, class: Host do
    name "localhost"
    hostname { `hostname`.chomp }
    user {ENV['USER']}
  end
end
