require 'resque'
require 'resque/server'

resque_config = YAML.load_file("#{Rails.root}/config/resque.yml")
Resque.redis = resque_config[Rails.env]