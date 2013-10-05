require 'faker'

namespace :db do
  desc "Fill database with sample data"
  task :populate => :environment do
    Rake::Task['db:mongoid:drop'].invoke
    Rake::Task['result_dir:drop'].invoke
    Rake::Task['resque:drop'].invoke

    FactoryGirl.create(:localhost, work_base_dir: "~/__work__")

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


  end
end

namespace :result_dir do
  desc "Remove the result directory"
  task :drop => :environment do
    root_dir = ResultDirectory.root
    FileUtils.rm_r(root_dir) if FileTest.directory?(root_dir)
  end
end
