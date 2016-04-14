class JobResult
  include Mongoid::Document

  field :result # can be any type. it's up to Simulator spec
  field :updated_at # this is used for sort. the value is copied from submittable
  belongs_to :submittable, polymorphic: true, autosave: false
  belongs_to :parameter_set, autosave: false
end
