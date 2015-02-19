source 'https://rubygems.org'

gem 'rails', '~> 4.2.0'
gem 'thin'
gem "mongoid"
gem "net-ssh"
gem "net-sftp"

# assets
gem "haml-rails"
gem "sass-rails"
gem 'therubyracer' # necessary to compile less
gem "less-rails", '2.3.3' # necessary for bootstrap. 2.3.3 is required. See http://stackoverflow.com/questions/19371695
gem 'twitter-bootstrap-rails', '2.2.6'
gem 'jquery-rails'
gem 'jquery-ui-rails'
gem 'jquery-datatables-rails'
gem "d3-rails"
gem "redcarpet"
gem 'dynatree-rails'

# for workers
gem 'daemon-spawn', :require => 'daemon_spawn'
gem "sys-filesystem"
gem "parallel"

# for cli
gem "ruby-progressbar"
gem "quiet_assets"

# utility tool
gem "pry"
gem "rspec-rails", '~>3.2' # must be in :development group to use the rake task 'spec'

group :test do
  gem "factory_girl_rails"
  gem "database_cleaner"
  gem "mongoid-rspec"
  gem "simplecov", :require => false
  gem "simplecov-rcov", :require => false
  gem "ci_reporter"
  gem "spork"
  gem "faker"
  if RUBY_VERSION >= '2.0.0'
    gem "pry-byebug"
  end
end

