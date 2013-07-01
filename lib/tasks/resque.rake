require "resque/tasks"
require "resque_scheduler/tasks"

task "resque:setup" do
  Rake::Task['environment'].invoke
end

namespace :resque  do

  desc "clean up resque database"
  task :drop => :environment do
    Resque.keys.each do |key|
      Resque.redis.del key
    end
  end
end
