require 'faker'

namespace :db do
  desc "Fill database with sample data"
  task :populate => :environment do
    Rake::Task['db:mongoid:drop'].invoke
    Rake::Task['result_dir:drop'].invoke
    Rake::Task['resque:drop'].invoke

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
    FactoryGirl.create(:simulator, parameter_sets_count: 0)
    FactoryGirl.create(:simulator, parameter_sets_count: 30)
    FactoryGirl.create(:simulator, runs_count: 30)

    # create simulator for IsingBcc model
    name = 'IsingBcc'
    execution_command = '~/program/acm2/spec/support/ising_bcc.sh'
    h = { "L" => {"type"=>"Integer", "description" => "System size"},
          "K" => {"type"=>"Float", "description" => "inverse temperature"},
          "tmax" => {"type"=>"Integer", "description" => "Simulation duration"}
        }
    sim = FactoryGirl.create(:simulator,
      name: name, execution_command: execution_command, parameter_definitions: h,
      parameter_sets_count: 0)
    10.times do |i|
      sim_prm = {"L" => 99, "K" => (15+i)*0.01, "tmax" => 256}
      sim.parameter_sets.create(sim_parameters: sim_prm)
    end
  end
end

namespace :result_dir do
  desc "Remove the result directory"
  task :drop => :environment do
    root_dir = ResultDirectory.root
    FileUtils.rm_r(root_dir) if FileTest.directory?(root_dir)
  end
end
