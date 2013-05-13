class Query
  include Origin::Queryable
end

class ParameterSetQuery
  include Mongoid::Document
  field :query, type: Hash
  def get_selector
    #p "in get_selector"
    h = {"v" => Query.new.where(self.query).selector}
    return h
  end
  def set_query(add_query)
    #p "in add_constraint"
    #p parameter_con
    #p Query.new.gte({"v.L" => 1}).where({"v.T" => 2.0}).selector
    q = Query.new.where(add_query)
    p q
    self.query = q.selector
    self.save
    p self.query
    p self.get_selector
    #p ParameterSet.where({"v.L" => 1}).first
    #p ParameterSet.where(q.selector).first
    return self.get_selector
  end
  def del_query(del_query)
    #p "in del_constraint"
    #p self
    tmp_query = ParameterSetQuery.where(:query => del_query)
    tmp_query.destroy if(ParameterSetQuery.where(:query => del_query).size==1)
    p ParameterSetQuery.where(:query => del_query).first
    #p ParameterQuery.where(:query => {"L"=>1, "T"=>2.0}).first
    return ParameterSetQuery.where(:query => {"L"=>1, "T"=>2.0}).size==0
  end
end
