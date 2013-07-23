source 'https://rubygems.org'

gem 'rails', '3.2.8'
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
  gem 'twitter-bootstrap-rails'
  gem 'jquery-datatables-rails'
  gem "haml-rails"
  gem "factory_girl_rails"
end

group :development, :test do
  gem "rspec-rails"
end

group :development do
  gem "quiet_assets"
  gem "faker"
  gem "pry"
end

group :test do
  gem "database_cleaner"
  gem "mongoid-rspec"
  gem "simplecov", :require => false
  gem "simplecov-rcov", :require => false
  gem "ci_reporter"
  gem "spork"
end
