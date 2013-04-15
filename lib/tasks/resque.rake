require "resque/tasks"

task "resque:setup" => :environment

namespace :resque  do

  desc "clean up resque database"
  task :drop => :environment do
    Resque.keys.each do |key|
      Resque.redis.del key
    end
  end
end