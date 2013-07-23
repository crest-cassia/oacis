require 'faker'

namespace :db do
  desc "Fill database with sample data"
  task :populate => :environment do
    Rake::Task['db:mongoid:drop'].invoke
    Rake::Task['result_dir:drop'].invoke
    Rake::Task['resque:drop'].invoke

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
    azrs = FactoryGirl.create_list(:analyzer, 2, simulator: sim, type: :on_parameter_set_group, run_analysis: true)
    FactoryGirl.create_list(:analysis, 10,
                            analyzer: azrs.first,
                            analyzable: sim.parameter_set_groups.first
                            )

    FactoryGirl.create(:simulator, parameter_sets_count: 0, parameter_set_queries_count: 0)
    # FactoryGirl.create(:simulator, parameter_sets_count: 30)
    # FactoryGirl.create(:simulator, runs_count: 30)

    FactoryGirl.create(:localhost, work_base_dir: "~/__work__")
  end
end

namespace :result_dir do
  desc "Remove the result directory"
  task :drop => :environment do
    root_dir = ResultDirectory.root
    FileUtils.rm_r(root_dir) if FileTest.directory?(root_dir)
  end
end
