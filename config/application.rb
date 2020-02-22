require_relative 'boot'

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
# require "active_record/railtie"
# require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "action_cable/engine"
require "sprockets/railtie"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Oacis
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 5.0

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.

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
  end
end

class Hash
  def to_s
    JSON.generate(self)
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
