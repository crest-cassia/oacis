source 'https://rubygems.org'

gem 'rails', '3.2.8'
gem 'jquery-rails'
gem "mongoid", ">= 3.0.9"
gem "haml", ">= 3.1.7"
gem "resque"
gem "resque-scheduler", :require => 'resque_scheduler'
gem "net-ssh", ">= 2.6.5"
gem "net-sftp", ">= 2.1.2"

group :assets do
  gem 'sass-rails',   '~> 3.2.3'
  gem 'uglifier', '>= 1.0.3'
  gem 'twitter-bootstrap-rails'
  gem 'jquery-datatables-rails'
  gem "haml-rails", ">= 0.3.5"
  gem "factory_girl_rails", ">= 4.1.0"
end

group :development, :test do
  gem "rspec-rails", ">= 2.13"
end

group :development do
  gem "quiet_assets", ">= 1.0.1"
  gem "faker"
  gem "pry"
end

group :test do
  gem "database_cleaner", ">= 0.9.1"
  gem "mongoid-rspec", ">= 1.4.6"
  gem "simplecov", :require => false
  gem "simplecov-rcov", :require => false
  gem "ci_reporter"
  gem "spork"
end
