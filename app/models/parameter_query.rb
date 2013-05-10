class Query
  include Origin::Queryable
end

class ParameterQuery
  include Mongoid::Document
  field :query, type: Hash
  def get_selector
    #p "in get_selector"
    h = {"v" => self.query}
    return h
  end
  def add_constraint(parameter_con)
    p "in add_constraint"
    p parameter_con
    #p q = Query.new.gte({"v.L" => 1}).where({"v.T" => 2.0})
    #p ParameterSet.where({"v.L" => 1}).first
    #p ParameterSet.where(q.selector).first
    return get_selector
  end
  def del_constraint()
    return get_selector
  end
end
