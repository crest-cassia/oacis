class LoggerForWorker

  # Same format as the one defined in config/environments/{development,production}.rb.
  # Defined here as well because those copies do not exist in the test environment.
  class LoggerFormatWithTime
    def call(severity, timestamp, progname, msg)
      format = "[%s] %5s -- %s: %s\n"
      format % ["#{timestamp.strftime("%Y/%m/%d %H:%M:%S")}.#{'%06d' % timestamp.usec.to_s}", severity, progname, String === msg ? msg : msg.inspect]
    end
  end

  LEVELS = { debug: 0, info: 1, warn: 2, error: 3, fatal: 4 }

  def initialize(worker_type, logdev, shift_age=0, shift_size=1048576)
    @type = worker_type
    @logger = Logger.new(logdev, shift_age, shift_size)
    @logger.formatter = LoggerFormatWithTime.new
    @logger.level = Logger::DEBUG
  end

  def send_by_cable(message, severity = :debug)
    s = @logger.formatter.call(severity, DateTime.now, nil, message.to_s.force_encoding('utf-8').scrub)
    WorkerLogChannel.broadcast_to('message', {@type => s})
  end

  LEVELS.each do |severity, level|
    define_method(severity) do |message|
      send_by_cable(message, severity)
      @logger.public_send(severity, message)
      # debug messages are not persisted to avoid bloating the collection
      WorkerLog.create({worker: @type, level: level, message: message}) if level >= LEVELS[:info]
    end
  end
end
