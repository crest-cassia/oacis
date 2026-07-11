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
    config.load_defaults 7.0

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
    config.autoload_paths += %W(#{config.root}/lib)
    config.eager_load_paths += %W(#{config.root}/lib)
    # lib/cli defines OacisCli with its own require_relative chain, and
    # lib/tasks holds boot scripts; neither follows Zeitwerk conventions.
    Rails.autoloaders.main.ignore(
      "#{config.root}/lib/cli",
      "#{config.root}/lib/tasks",
      "#{config.root}/lib/assets"
    )
    # Acronym-style constants that Zeitwerk cannot infer from file names.
    Rails.autoloaders.each do |autoloader|
      autoloader.inflector.inflect(
        "ssh_util" => "SSHUtil",
        "popen_ssh" => "PopenSSH"
      )
    end

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
      config.user_config = YAML.safe_load(File.read(user_config_yml), permitted_classes: [Symbol], aliases: true)
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
