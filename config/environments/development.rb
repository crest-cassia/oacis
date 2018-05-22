Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports.
  config.consider_all_requests_local = true

  # Enable/disable caching. By default caching is disabled.
  if Rails.root.join('tmp/caching-dev.txt').exist?
    config.action_controller.perform_caching = true

    config.cache_store = :memory_store
    config.public_file_server.headers = {
      'Cache-Control' => 'public, max-age=172800'
    }
  else
    config.action_controller.perform_caching = false

    config.cache_store = :null_store
  end

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = false

  config.action_mailer.perform_caching = false

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise an error on page load if there are pending migrations.
  # config.active_record.migration_error = :page_load

  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  config.assets.debug = true

  # Suppress logger output for asset requests.
  config.assets.quiet = true

  # Raises error for missing translations
  # config.action_view.raise_on_missing_translations = true

  # Use an evented file watcher to asynchronously detect changes in source code,
  # routes, locales, etc. This feature depends on the listen gem.
  # config.file_watcher = ActiveSupport::EventedFileUpdateChecker


  # user code -----------
  class LoggerFormatWithTime
    def call(severity, timestamp, progname, msg)
      format = "[%s] %5s -- %s: %s\n"
      format % ["#{timestamp.strftime("%Y/%m/%d %H:%M:%S")}.#{'%06d' % timestamp.usec.to_s}", severity, progname, String === msg ? msg : msg.inspect]
    end
  end
  config.log_level = :error
  FileUtils.mkdir_p( Rails.root.join("log") )
  config.logger = Logger.new(Rails.root.join("log/development.log"), 5, 1.megabytes)
  config.logger.formatter = LoggerFormatWithTime.new
  Mongoid.logger.level = Logger::WARN
  Mongoid.logger.formatter = LoggerFormatWithTime.new
  Mongo::Logger.logger.level = Logger::WARN
  Mongo::Logger.logger.formatter = LoggerFormatWithTime.new
end
