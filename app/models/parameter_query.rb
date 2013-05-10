class ParameterQuery
  include Mongoid::Document
  field :query, type: Hash
end
