Resque.redis = Redis.new(host: 'localhost', port: 6379)
Resque.logger = Logger.new(Rails.root.join('log', "#{Rails.env}_resque.log"), 5, 1.megabytes)
Resque.logger.level = Logger::ERROR
