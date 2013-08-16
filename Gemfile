source 'https://rubygems.org'

gem 'rails', '3.2.13'
gem 'jquery-rails'
gem "mongoid"
gem "haml"
gem "resque"
gem "resque-scheduler", :require => 'resque_scheduler'
gem "net-ssh"
gem "net-sftp"

group :assets do
  gem 'sass-rails'
  gem 'uglifier'
  gem 'therubyracer'
  gem "less-rails"
  gem 'twitter-bootstrap-rails', '2.2.6'
  gem 'jquery-datatables-rails'
  gem "haml-rails"
  gem "factory_girl_rails"
end

group :development, :test do
  gem "rspec-rails"
  gem "pry"
end

group :development do
  gem "quiet_assets"
  gem "faker"
end

group :test do
  gem "database_cleaner"
  gem "mongoid-rspec"
  gem "simplecov", :require => false
  gem "simplecov-rcov", :require => false
  gem "ci_reporter"
  gem "spork"
end
