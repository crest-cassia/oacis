require 'resque/tasks'

namespace :resque do
  task setup: :environment do
    ENV['TERM_CHILD'] ||= '1'
    ENV['QUEUE'] ||= '*'
    require 'resque'
  end
end
