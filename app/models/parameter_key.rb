class ParameterKey
  include Mongoid::Document
  include Mongoid::Timestamps
  field :name, type: String
  field :type, type: String
  field :default
  # field :restriction, type: String  # TODO : implement me
  field :description, type: String

  validates :name, presence: true, uniqueness: true
  validates :type, presence: true, inclusion: ["Boolean","Integer","Float","String"]
end
