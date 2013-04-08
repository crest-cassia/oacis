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
    simulator_fields = {
      name:"simulatorA",
      parameter_keys: {
        "L" => {"type" => "Integer"},
        "T" => {"type" => "Float"}
      },
      execution_command: "~/path_to_simulator_a",
    }
    Simulator.create!(simulator_fields)
    simulator_fields = {
      name:"simulatorB",
      parameter_keys: {
        "Time_step" => {"type" => "Integer"},
        "Velocity" => {"type" => "Float"},
        "Density" => {"type" => "Float"}
      },
      execution_command: "~/path_to_simulator_b",
    }
    Simulator.create!(simulator_fields)

  end
end
      
