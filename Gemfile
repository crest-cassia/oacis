source 'https://rubygems.org'

gem 'rails', '~> 3.2.0'
gem "mongoid"
gem "net-ssh"
gem "net-sftp"

# assets
gem "haml-rails"
gem 'therubyracer' # necessary to compile less
gem "less-rails"   # necessary for bootstrap
gem 'twitter-bootstrap-rails', '2.2.6'
gem 'jquery-rails'
gem 'jquery-datatables-rails'
gem "d3-rails"
gem "redcarpet"

# for workers
gem 'daemon-spawn', :require => 'daemon_spawn'
gem "sys-filesystem"

# for cli
gem "ruby-progressbar"
gem "parallel"
gem "quiet_assets"

# utility tool
gem "pry"
gem "rspec-rails" # must be in :development group to use the rake task 'spec'

group :test do
  gem "factory_girl_rails"
  gem "database_cleaner"
  gem "mongoid-rspec"
  gem "simplecov", :require => false
  gem "simplecov-rcov", :require => false
  gem "ci_reporter"
  gem "spork"
  gem "faker"
end

