require_relative 'boot'

# require 'rails/all'
# Pick the frameworks you want:
# require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "sprockets/railtie"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module AcmProto
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # don't generate RSpec tests for views and helpers
    config.generators do |g|
      g.test_framework :rspec, fixture: true
      g.fixture_replacement :factory_bot
      g.view_specs false
      g.helper_specs false
    end

    # Custom directories with classes and modules you want to be autoloadable.
    config.enable_dependency_loading = true
    config.autoload_paths += %W(#{config.root}/lib)

    # get local timezone name
    jan_offset = Time.now.beginning_of_year.utc_offset
    jul_offset = Time.now.beginning_of_year.change(month: 7).utc_offset
    offset = jan_offset < jul_offset ? jan_offset : jul_offset
    zone = ActiveSupport::TimeZone.all.find {|z| z.utc_offset==offset}.name
    config.time_zone = zone

    # load user config
    config.user_config = {}
    user_config_yml = Rails.root.join("config/user_config.yml")
    if File.exist? user_config_yml
      config.user_config = YAML.load(File.open(user_config_yml))
    end

    # for use resque. default is Async.
    config.active_job.queue_adapter = :resque
    config.active_job.queue_name_prefix = Rails.env
  end
end

module JSON
  def self.is_json?(foo)
    begin
      return false unless foo.is_a?(String)
      JSON.parse(foo)
      true
    rescue JSON::ParserError
      false
    end
  end

  def self.is_not_json?(foo)
    return ! self.is_json?(foo)
  end
end
