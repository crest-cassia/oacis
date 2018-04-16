class LoggerForWorker

  def initialize(worker_type, logdev, shift_age=0, shift_size=1048576)
    @type = worker_type
    @logger = Logger.new(logdev, shift_age, shift_size)
    @logger.formatter = LoggerFormatWithTime.new
    @logger.level = Logger::DEBUG
  end

  def send_by_cable(message, severity = :debug)
    s = @logger.formatter.call(severity, DateTime.now, nil, message)
    WorkerLogChannel.broadcast_to('message', {@type => s})
  end

  def debug(message)
    send_by_cable(message, :debug)
    @logger.debug(message)
  end

  def info(message)
    send_by_cable(message, :info)
    @logger.info(message)
    WorkerLog.create({worker: @type, level: 1, message: message})
  end

  def warn(message)
    send_by_cable(message, :warn)
    @logger.warn(message)
    WorkerLog.create({worker: @type, level: 2, message: message})
  end

  def error(message)
    send_by_cable(message, :error)
    @logger.error(message)
    WorkerLog.create({worker: @type, level: 3, message: message})
  end

  def fatal(message)
    send_by_cable(message, :fatal)
    @logger.fatal(message)
    WorkerLog.create({worker: @type, level: 4, message: message})
  end
end
