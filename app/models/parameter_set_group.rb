class ParameterSetGroup
  include Mongoid::Document
  include Mongoid::Timestamps

  belongs_to :simulator
  has_and_belongs_to_many :parameter_sets
  embeds_many :analysis_runs, as: :analyzable
end
