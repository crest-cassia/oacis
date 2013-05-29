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
    sim = FactoryGirl.create(:simulator,
                             parameter_sets_count: 5,
                             runs_count: 2,
                             finished_runs_count: 3,
                             analyzers_count: 2,
                             run_analysis: false,
                             analyzers_on_parameter_set_count: 2,
                             run_analysis_on_parameter_set: false,
                             parameter_set_queries_count: 5
                             )

    FactoryGirl.create(:simulator, parameter_sets_count: 0, parameter_set_queries_count: 0)
    # FactoryGirl.create(:simulator, parameter_sets_count: 30)
    # FactoryGirl.create(:simulator, runs_count: 30)

    # create simulator for IsingBcc model
    # name = 'IsingBcc'
    # command = '~/program/acm2/spec/support/ising_bcc.sh'
    # h = { "L" => {"type"=>"Integer", "description" => "System size"},
    #       "K" => {"type"=>"Float", "description" => "inverse temperature"},
    #       "tmax" => {"type"=>"Integer", "description" => "Simulation duration"}
    #     }
    # sim = FactoryGirl.create(:simulator,
    #   name: name, command: command, parameter_definitions: h,
    #   parameter_sets_count: 0,
    #   analyzers_count: 0
    #   )
    # 10.times do |i|
    #   sim_prm = {"L" => 99, "K" => (15+i)*0.01, "tmax" => 256}
    #   sim.parameter_sets.create(v: sim_prm)
    # end

    FactoryGirl.create_list(:host, 5)
  end
end

namespace :result_dir do
  desc "Remove the result directory"
  task :drop => :environment do
    root_dir = ResultDirectory.root
    FileUtils.rm_r(root_dir) if FileTest.directory?(root_dir)
  end
end
