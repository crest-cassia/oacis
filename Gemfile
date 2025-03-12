# source 'https://rubygems.org'
# Commented out to avoid duplicate `source`. Primary source is specified in rb_call/Gemfile.

gem 'rails', '~> 5.2'
gem "puma"
gem "mongoid", ' ~> 7.0'
gem "net-ssh", '~> 7.2'
gem "ed25519", '>= 1.2', '< 2.0'  # support openssh format: https://github.com/net-ssh/net-ssh/issues/478
gem "bcrypt_pbkdf", '>= 1.0', '< 2.0'
gem "jbuilder"
gem "redis", '~> 3.0'
gem "e2mmap"  # since ruby 2.7.0, e2mmap is removed from the standard library

gem 'bootsnap', require: false

# assets
gem "sprockets"
gem 'record_tag_helper', '~> 1.0'
  # fix version of sprockets to prevent deprecation warning.
  # should be updated after less-rails fixed issue https://github.com/metaskills/less-rails/issues/122
gem "haml-rails"
gem "sass-rails"
gem 'jquery-rails'
gem 'jquery-ui-rails'
gem 'jquery-datatables-rails', ' ~> 3.2.0'
gem "d3-rails", '~> 3.4'
gem "redcarpet"
gem 'dynatree-rails'
gem 'bootstrap-sass'
gem 'bootswatch-rails'
gem 'font-awesome-rails'
gem 'rubyzip'

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
  gem "faker"
  if RUBY_VERSION >= '2.0.0'
    gem "pry-byebug"
  end
end

eval_gemfile "#{File.dirname(__FILE__)}/rb_call/Gemfile"
