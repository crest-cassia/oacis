class SaveTask
  include Mongoid::Document
  field :ps_params, type: Array
  field :run_param, type: Hash
  field :num_runs, type: Integer
  field :simulator_id, type: String
  field :cancel_flag, type: Boolean, default: false
  field :creation_size, type: Integer

  validates :ps_params, presence: true
  validates :num_runs, presence: true
  validates :simulator_id, presence: true
  validates :creation_size, presence: true
end
