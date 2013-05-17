class Query
  include Origin::Queryable
end

class ParameterSetQuery
  include Mongoid::Document
  field :query, type: Hash
  belongs_to :simulator
  validates :simulator, presence: true
  validates :query, presence: true, uniqueness: {:scope => :simulator_id}#, format: {with: /\A\w+\z/}, if: simulator {|x| x.parameter_set_query.include?(self)}
  validate :query_format_is_valid, on: :create
  
  NumMatchTypes = ["eq", "ne", "gt", "gte", "lt", "lte"]
  BooleanMatchTypes = ["true", "false"]
  StringMatchTypes = ["start_with", "end_with", "include", "match"]

  def query_format_is_valid
    if self.query.is_a?(Hash)
      self.query.each do |key,val|
        if (self.simulator.parameter_definitions.has_key?(key))
          if val.is_a?(Hash)
            val.each do |inkey,inval|
              if(self.simulator.parameter_definitions[key]["type"]=="Integer" || self.simulator.parameter_definitions[key]["type"]=="Float")
                case inkey
                when "eq", "ne", "gt", "gte", "lt", "lte"
                  self.errors.add(:query, "type(num) missmatch in psq.query") unless inval.is_a?(Integer) || inval.is_a?(Float) 
                else
                  self.errors.add(:query, "undefined matcher(num) in psq.query")
                end
              elsif(self.simulator.parameter_definitions[key]["type"]=="Boolean")
                case inkey
                when "true", "false"
                  self.errors.add(:query, "type(num) missmatch in psq.query") unless inval.is_a?(TrueClass) 
                else
                  self.errors.add(:query, "undefined matcher(num) in psq.query")
                end
              elsif(self.simulator.parameter_definitions[key]["type"]=="String")
                case inkey
                when "start_with", "end_with", "include", "match"
                  self.errors.add(:query, "type(num) missmatch in psq.query") unless inval.is_a?(String) 
                else
                  self.errors.add(:query, "undefined matcher(num) in psq.query")
                end
              else
                self.errors.add(:query, "undefined parameter type")
              end
            end
          else
            self.errors.add(:query, "query does not have defined value")
          end
        else
          self.errors.add(:query, "query does not have keys in parametr_definitions")
        end
      end
    else
      self.errors.add(:query, "query is not a Hash")
    end
  end
  
  #comvert format from string to selector
  def get_selector
    p self.query
    q = Query.new
    self.query.each do |key,val|
      h = {}
      val.each do |inkey,inval|
        if(self.simulator.parameter_definitions[key]["type"]=="Integer")
          case inkey
          when "eq"
            if(inval.is_a?(Integer))
              h = {"v."+key => inval}
            else
              self.errors.add(:get_selector, "val is not a Integer")
            end
          when "ne", "gt", "gte", "lt", "lte"
            if(inval.is_a?(Integer))
              h = {"v."+key => {"$"+inkey.to_s => inval}}
            else
              self.errors.add(:get_selector, "val is not a Integer")
            end
          end
        elsif(self.simulator.parameter_definitions[key]["type"]=="Float")
          case inkey
          when "eq"
            if(inval.is_a?(Float))
              h = {"v."+key => inval}
            else
              self.errors.add(:get_selector, "val is not a Float")
            end
          when "ne", "gt", "gte", "lt", "lte"
            if(inval.is_a?(Float))
              h = {"v."+key => {"$"+inkey.to_s => inval}}
            else
              self.errors.add(:get_selector, "val is not a Float")
            end
          end
        elsif(self.simulator.parameter_definitions[key]["type"]=="Boolean")
          self.errors.add(:get_selector, "macher is not defind for Boolean")
        elsif(self.simulator.parameter_definitions[key]["type"]=="String")
          self.errors.add(:get_selector, "macher is not defind for String")
        end
        p h
        q = q.where(h)
      end
    end
    #p q.selector
    #p Query.new.where({"v.L" => 2}).gte({"v.T" => 4.0}).selector
    return q.selector
  end
  
  #ser a query which is a hash expressed with string in key and val
  def set_query(params)
    result = true
    #p "in set_query"
    h = {}
    #p params
    #p params['param']
    params['param'].each_with_index do |para, idx|
      p para.to_s
      p params['macher'][idx]
      p params['value'][idx]
      if(self.simulator.parameter_definitions[para]["type"]=="Integer")
        if(params['value'][idx].to_i.is_a?(Integer))
          h[para.to_s] = {params['macher'][idx]=>params['value'][idx].to_i}
        else
          self.errors.add(:set_query, "val not match to Integer")
          result = false
        end
      elsif(self.simulator.parameter_definitions[para]["type"]=="Float")
        if(params['value'][idx].to_f.is_a?(Float))
          h[para.to_s] = {params['macher'][idx]=>params['value'][idx].to_f}
        else
          self.errors.add(:set_query, "val not match to float")
          result = false
        end
      elsif(self.simulator.parameter_definitions[para]["type"]=="Boolean")
        if(params['value'][idx]=="true")
          h[para.to_s] = {params['macher'][idx]=>true}
        elsif(params['value'][idx]=="false")
          h[para.to_s] = {params['macher'][idx]=>false}
        else
          self.errors.add(:set_query, "val not match to boolean")
          result = false
        end
      elsif(self.simulator.parameter_definitions[para]["type"]=="String")
        unless(params['value'][idx].to_s.include?("$"))
          h[para.to_s] = {params['macher'][idx]=>params['value'][idx].to_s}
        else
          self.errors.add(:set_query, "string val has \"$\"")
          result = false
        end
      else
        result = false
      end
    end
    self.query = h
    #p self
    self.save
    #p ParameterSet.where({"v.L" => 1}).first
    #p ParameterSet.where(q.selector).first
    return self.query
  end
end
