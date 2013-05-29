class Query
  include Origin::Queryable
end

class ParameterSetQuery
  include Mongoid::Document
  field :query, type: Hash
  belongs_to :simulator
  validates :simulator, presence: true
  validates :query, presence: true
  validate :validate_uniqueness_of_query, message: 'must be unique'
  validate :validate_format_of_query, message: 'format must be valid'

  NumTypeMatchers = ["eq", "ne", "gt", "gte", "lt", "lte"]
  NumTypeMatcherStrings = ["==", "!=", ">", ">=", "<", "<="]
  BooleanTypeMatchers = ["eq", "ne"]
  StringTypeMatchers = ["start_with", "end_with", "include", "match"]

  def validate_uniqueness_of_query
    if self.query.blank?
      self.errors.add(:query, "query is empty")
      return
    end

    if ParameterSetQuery.where(simulator: simulator, query: query).count > 0
      self.errors.add(:query, "must be unique")
    end
  end

  def validate_format_of_query
    unless !self.query.blank? && self.query.is_a?(Hash)
      self.errors.add(:query, "query is not a Hash")
      return
    end

    self.query.each do |key,criteria|
      unless simulator.parameter_definitions.has_key?(key)
        self.errors.add(:query, "defined keys and/or values are not exist in parametr_definitions")
        return
      end

      unless criteria.is_a?(Hash)
        self.errors.add(:query, "criteria of query must be a Hash")
        return
      end

      # validate format of a matcher
      criteria.each do |matcher, value|
        type = self.simulator.parameter_definitions[key]["type"]
        valid_matchers = []
        case type
        when "Integer", "Float"
          valid_matchers = NumTypeMatchers
        when "Boolean"
          valid_matchers = BooleanTypeMatchers
        when "String"
          valid_matchers = StringTypeMatchers
        else
          raise "Not supported type"
        end
        unless valid_matchers.include?(matcher)
          self.errors.add(:set_query, "unknown matcher : #{matcher}")
          return false
        end

        # validate type of a value
        klass = Kernel.const_get(type)
        unless value.is_a?(klass)
          self.errors.add(:query, "#{value.inspect} is not a #{type}")
          return false
        end
      end
    end

  end

  #convert format from string to selector
  def selector
    q = Query.new
    self.query.each do |key,val|
      h = {}
      type = self.simulator.parameter_definitions[key]["type"]
      val.each do |inkey,inval|
        case type
        when "Integer", "Float"
          case inkey
          when NumTypeMatchers[0]
            h = {"v."+key => inval}
          when *NumTypeMatchers[1..5]
            h = {"v."+key => {"$"+inkey.to_s => inval}}
          else
            raise "undefined matcher #{inkey} for #{type}"
          end
        when "Boolean"
          case inkey
          when BooleanTypeMatchers[0]
            h = {"v."+key => inval}
          when BooleanTypeMatchers[1]
            h = {"v."+key => {"$"+inkey.to_s => inval}}
          else
            raise "undefined matcher #{inkey} for (Boolean)"
          end
        when "String"
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
            raise "undefined matcher #{inkey} for (String)"
          end
        end
        q = q.where(h)
      end
    end
    return q.selector
  end
  
  #ser a query which is a hash expressed with string in key and val
  def set_query(settings)
    return false if settings.blank?

    h = {}
    settings.each do |para|
      parameter = para['param']
      type = self.simulator.parameter_definitions[parameter]['type']
      value = para['value']
      matcher = para['matcher']

      # cast value to the specified type
      casted_value = ParametersUtil.cast_value(value, type)
      if casted_value.nil?
        self.errors.add(:set_query, "value (#{value}) is not valid as a #{type}")
        return false
      end

      h[parameter] = { matcher => casted_value }
    end

    #h includes one or more hash(s) that can be converted to selector(s)
    self.query = h
  end
end
