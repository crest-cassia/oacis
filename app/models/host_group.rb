class HostGroup
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String

  has_and_belongs_to_many :hosts

  validates :name, presence: true, uniqueness: true, length: {minimum: 1}
  validates :host_ids, length: {minimum: 1}

  def destroyable?
    true  # TODO: implement me
  end
end
