class SaveTask
  include Mongoid::Document
  field :ps_param, type: Array
  field :run_param, type: Hash
  field :run_num, type: Integer
  field :simulator_id, type: String
  field :cancel_flag, type: Boolean, default: false

  validates :ps_param, presence: true
  validates :run_param, presence: true
  validates :run_num, presence: true
  validates :simulator_id, presence: true
end
