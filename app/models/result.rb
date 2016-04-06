class Result
  include Mongoid::Document

  field :result # can be any type. it's up to Simulator spec
  belongs_to :submittable, polymorphic: true, autosave: false
end
