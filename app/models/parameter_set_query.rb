class Query
  include Origin::Queryable
end

class ParameterSetQuery
  include Mongoid::Document
  field :query, type: Hash
  belongs_to :simulator
  validates :simulator, presence: {message: 'simulator must be presence'}
  validates :query, presence: {message: 'query must be presence'}
  validate :query_field_is_valid, message: 'must be unique'
  validate :query_format_is_valid, on: :create, message: 'format must be valid'

  NumTypeMatchers = ["eq", "ne", "gt", "gte", "lt", "lte"]
  NumTypeMatcherStrings = ["==", "!=", ">", ">=", "<", "<="]
  BooleanTypeMatchers = ["eq", "ne"]
  StringTypeMatchers = ["start_with", "end_with", "include", "match"]

  def query_field_is_valid
    if self.query.blank?
      self.errors.add(:query, "query is empty")
      return
    end

    ParameterSetQuery.where(:simulator => self.simulator).each do |psq|
      if psq.selector.eql?(self.selector)
        self.errors.add(:query, "query is not unique") 
      end
    end
  end

  def query_format_is_valid
    unless !self.query.blank? && self.query.is_a?(Hash)
      self.errors.add(:query, "query is not a Hash")
      return
    end

    self.query.each do |key,val|
      unless (self.simulator.parameter_definitions.has_key?(key)) && val.is_a?(Hash)
        self.errors.add(:query, "defined keys and/or values are not exist in parametr_definitions")
        return
      end

      val.each do |inkey,inval|
        case self.simulator.parameter_definitions[key]["type"]
        when "Integer", "Float"
          unless NumTypeMatchers.include?(inkey) && (inval.is_a?(Integer) || inval.is_a?(Float))
            self.errors.add(:query, "Type is not Integer or Float, or undefined matcher for Integer or Float")
          end
        when "Boolean"
          unless BooleanTypeMatchers.include?(inkey) && inval.is_a?(Boolean)
            self.errors.add(:query, "Type is not Boolean, or undefined matcher for Booleans")
          end
        when "String"
          unless StringTypeMatchers.include?(inkey) && inval.is_a?(String) && inval != "" && !inval.include?("$")
            self.errors.add(:query, "Type is not String, or undefined matcher for String")
          end
        else
          self.errors.add(:query, "undefined parameter type")
        end
      end
    end
  end
  
  #convert format from string to selector
  def selector
    q = Query.new
    self.query.each do |key,val|
      h = {}
      val.each do |inkey,inval|
        if(self.simulator.parameter_definitions[key]["type"]=="Integer")
          unless(inval.is_a?(Integer))
            self.errors.add(:selector, "val is not a Integer")
            return q.where(h).selector
          end

          case inkey
          when NumTypeMatchers[0]
            h = {"v."+key => inval}
          when *NumTypeMatchers[1..5]
            h = {"v."+key => {"$"+inkey.to_s => inval}}
          else
            self.errors.add(:selector, "undefined matcher for (Integer)")
          end
          
        elsif(self.simulator.parameter_definitions[key]["type"]=="Float")
          unless(inval.is_a?(Float))
            self.errors.add(:selector, "val is not a Integer")
            return q.where(h).selector
          end

          case inkey
          when NumTypeMatchers[0]
            h = {"v."+key => inval}
          when *NumTypeMatchers[1..5]
            h = {"v."+key => {"$"+inkey.to_s => inval}}
          else
            self.errors.add(:selector, "undefined matcher for (Float)")
          end

        elsif(self.simulator.parameter_definitions[key]["type"]=="Boolean")
          unless(inval.is_a?(Boolean))
            self.errors.add(:selector, "val is not a Boolean")
            return q.where(h).selector
          end

          case inkey
          when BooleanTypeMatchers[0]
            h = {"v."+key => inval}
          when BooleanTypeMatchers[1]
            h = {"v."+key => {"$"+inkey.to_s => inval}}
          else
            self.errors.add(:selector, "undefined matcher for (Boolean)")
          end
          
        elsif(self.simulator.parameter_definitions[key]["type"]=="String")
          unless(inval.is_a?(String))
            self.errors.add(:selector, "val is not a String")
            return q.where(h).selector
          end

          case inkey
          when StringTypeMatchers[0]
            h = {"v."+key => Regexp.new("^"+inval)}
          when StringTypeMatchers[1]
            h = {"v."+key => Regexp.new(inval+"$")}
          when StringTypeMatchers[2]
            h = {"v."+key => Regexp.new(inval)}
          when StringTypeMatchers[3]
            h = {"v."+key => Regexp.new(inval)}
          else
            self.errors.add(:selector, "undefined matcher for (String)")
          end
        end

        q = q.where(h)
      end
    end
    return q.selector
  end
  
  #ser a query which is a hash expressed with string in key and val
  def set_query(settings)
    if settings.blank?
      return false
    end
    h = {}
    settings.each do |para|
      case self.simulator.parameter_definitions[para['param']]["type"]
      when "Integer"
        if(para['value'].to_i.is_a?(Integer))
          h[para['param'].to_s] = {para['matcher']=>para['value'].to_i}
        else
          self.errors.add(:set_query, "val not match to Integer")
          return false
        end
      when "Float"
        if(para['value'].to_f.is_a?(Float))
          h[para['param'].to_s] = {para['matcher']=>para['value'].to_f}
        else
          self.errors.add(:set_query, "val not match to float")
          return false
        end
      when "Boolean"
        if(para['value']=="true")
          h[para['param'].to_s] = {para['matcher']=>true}
        elsif(para['value']=="false")
          h[para['param'].to_s] = {para['matcher']=>false}
        else
          self.errors.add(:set_query, "val not match to boolean")
          return false
        end
      when "String"
        unless(para['value'].to_s.include?("$"))
          h[para['param'].to_s] = {para['matcher']=>para['value'].to_s}
        else
          self.errors.add(:set_query, "string val has \"$\"")
          return false
        end
      else
        self.errors.add(:set_query, "undefined types")
        return false
      end
    end

    #h includes one or more hash(s) that can be converted to selector(s)
    self.query = h
    return h
  end
end
