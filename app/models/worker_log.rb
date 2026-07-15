class WorkerLog
  include Mongoid::Document
  include Mongoid::Timestamps::Created

  field :w, type: String, as: :worker
  field :l, type: Integer, as: :level
  field :m, type: String, as: :message

  # old logs are removed by MongoDB's TTL mechanism
  LOG_RETENTION_PERIOD = 7.days
  index({ created_at: 1 }, { expire_after_seconds: LOG_RETENTION_PERIOD.to_i })

  SEVERITY = {
    4 => "FATAL",
    3 => "ERROR",
    2 => "WARN",
    1 => "INFO",
    0 => "DEBUG"
  }

end
