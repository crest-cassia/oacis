require 'faker'

namespace :db do
  desc "Fill database with sample data"
  task :populate => :environment do
    Rake::Task['db:mongoid:drop'].invoke

    # create users
    User.create!(:name => "Example User",
                 :email => "example@example.com",
                 :password => "foobar",
                 :password_confirmation => "foobar")
    9.times do |n|
      name = Faker::Name.name
      email = "example-#{n+1}@example.com"
      password = "password"
      User.create!(:name => name,
                   :email => email,
                   :password => password,
                   :password_confirmation => password)
    end

    # create simulators
    FactoryGirl.create(:simulator)
    FactoryGirl.create(:simulator, parameters_count: 0)
    FactoryGirl.create(:simulator, parameters_count: 100)
    FactoryGirl.create(:simulator, runs_count: 100)
  end
end
      
