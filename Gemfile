source 'https://rubygems.org'

gem 'rails', '~> 5.0.0'
gem "puma"
gem "mongoid", ' ~> 6.1.0'
gem "net-ssh"
gem "net-sftp"
gem "jbuilder"

# assets
gem "sprockets", '3.6.3'
gem 'record_tag_helper', '~> 1.0'
  # fix version of sprockets to prevent deprecation warning.
  # should be updated after less-rails fixed issue https://github.com/metaskills/less-rails/issues/122
gem "haml-rails"
gem "sass-rails"
gem 'therubyracer' # necessary to compile less
gem "less-rails"   # necessary for bootstrap.
gem 'twitter-bootstrap-rails', ' ~> 3.2.0'
gem 'jquery-rails'
gem 'jquery-ui-rails'
gem 'jquery-datatables-rails', ' ~> 3.2.0'
gem "d3-rails", '~> 3.4'
gem "redcarpet"
gem 'dynatree-rails'

# for workers
gem 'daemon-spawn', :require => 'daemon_spawn'
gem "sys-filesystem"

# for cli
gem "ruby-progressbar"

# utility tool
gem "pry"
gem "pry-rails"
gem "rspec-rails", '~>3.5' # must be in :development group to use the rake task 'spec'
gem "stackprof"

group :test do
  gem "factory_bot_rails"
  gem "database_cleaner"
  gem 'rails-controller-testing'
  gem "simplecov", :require => false
  gem "simplecov-rcov", :require => false
  gem "ci_reporter", '~> 1.9'
  gem "faker"
  if RUBY_VERSION >= '2.0.0'
    gem "pry-byebug"
  end
end

eval_gemfile "#{File.dirname(__FILE__)}/rb_call/Gemfile"

