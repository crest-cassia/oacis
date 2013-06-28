require "resque/tasks"
require "resque_scheduler/tasks"

task "resque:setup" do
  if ENV['LOAD_RAILS'] == 'false'
    Rake::Task["resque:preload"].clear
    require "#{Rails.root}/config/initializers/resque"
    require "#{Rails.root}/app/workers/simulator_runner"
  else
    Rake::Task['environment'].invoke
  end
end

namespace :resque  do

  desc "clean up resque database"
  task :drop => :environment do
    Resque.keys.each do |key|
      Resque.redis.del key
    end
  end
end