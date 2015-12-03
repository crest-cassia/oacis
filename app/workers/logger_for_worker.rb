class LoggerForWorker

  def initialize(worker_type, logdev, shift_age=0, shift_size=1048576)
    @type = worker_type
    @logger = Logger.new(logdev, shift_age, shift_size)
    @logger.formatter = LoggerFormatWithTime.new
    @logger.level = Logger::DEBUG
  end

  def debug(message)
    @logger.debug(message)
  end

  def info(message)
    @logger.info(message)
    WorkerLog.create({worker: @type, level: 1, message: message})
  end

  def warn(message)
    @logger.warn(message)
    WorkerLog.create({worker: @type, level: 2, message: message})
  end

  def error(message)
    @logger.error(message)
    WorkerLog.create({worker: @type, level: 3, message: message})
  end

  def fatal(message)
    @logger.fatal(message)
    WorkerLog.create({worker: @type, level: 4, message: message})
  end
end
