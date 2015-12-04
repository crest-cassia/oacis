class WorkerLog
  include Mongoid::Document
  include Mongoid::Timestamps::Created

  field :w, type: String, as: :worker
  field :l, type: Integer, as: :level
  field :m, type: String, as: :message

  SEVERITY = {
    4 => "FATAL",
    3 => "ERROR",
    2 => "WARN",
    1 => "INFO",
    0 => "DEBUG"
  }

end
