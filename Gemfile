source 'https://rubygems.org'

gem 'rails', '~> 7.0.8'
gem "puma"
gem "mongoid", '~> 8.1'
gem "net-ssh", '~> 7.2'
gem "ed25519", '>= 1.2', '< 2.0'  # support openssh format: https://github.com/net-ssh/net-ssh/issues/478
gem "bcrypt_pbkdf", '>= 1.0', '< 2.0'
gem "jbuilder"
gem "redis", '~> 4.8'

gem 'bootsnap', require: false
gem 'concurrent-ruby', '< 1.3.5'  # 1.3.5 dropped `require "logger"`, breaking Rails < 7.1; remove after Rails 7.1+

# assets
gem "sprockets", '~> 3.7'  # sprockets 4 requires app/assets/config/manifest.js; upgrade separately
gem "haml-rails", '~> 2.1'
gem "sass-rails", '~> 6.0'
gem 'jquery-rails'
gem 'jquery-ui-rails'
gem 'jquery-datatables-rails', ' ~> 3.2.0'
gem "d3-rails", '~> 3.4'
gem "redcarpet"
gem 'dynatree-rails'
gem 'bootstrap-sass'
gem 'bootswatch-rails'
gem 'font-awesome-rails', '~> 4.7.0.9'
gem 'rubyzip'

# for workers
gem 'daemon-spawn', :require => 'daemon_spawn'
gem "sys-filesystem"

# for cli
gem "ruby-progressbar"

# utility tool
gem "pry"
gem "pry-rails"
gem "rspec-rails", '~> 6.1' # must be in :development group to use the rake task 'spec'
gem "stackprof"

group :test do
  gem "factory_bot_rails", '~> 6.0'
  gem "database_cleaner-mongoid"
  gem 'rails-controller-testing'
  gem "faker"
  gem "pry-byebug"
end
