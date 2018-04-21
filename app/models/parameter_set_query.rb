class ParameterSetQuery
  include Mongoid::Document
  field :name, type: String
  field :query, type: Array
  belongs_to :simulator
  validates :simulator, presence: true
  validates :query, presence: true
  validates :name, presence: true
  validates :name, uniqueness: { scope: [:simulator_id] }
  validate :validate_uniqueness_of_query
  validate :validate_format_of_query
  before_validation :cast_values

  NumTypeMatchers = ["eq", "ne", "gt", "gte", "lt", "lte"]
  NumTypeMatcherStrings = ["==", "!=", ">", ">=", "<", "<="]
  StringTypeMatchers = ["start_with", "end_with", "include", "match"]

  def validate_uniqueness_of_query
    if self.query.blank?
      self.errors.add(:query, "must not be blank")
      return
    end

    if ParameterSetQuery.where(simulator: simulator, query: query).count > 0
      self.errors.add(:query, "must be unique")
    end
  end

  def validate_format_of_query
    unless !self.query.blank? && self.query.is_a?(Array)
      self.errors.add(:query, "must be a Array")
      return false
    end

    self.query.each do |key,matcher,val|
      pd = simulator.parameter_definition_for(key)
      unless pd
        self.errors.add(:query, "#{key} is not a parameter")
        return false
      end
      type = pd.type
      unless supported_matchers(type).include?(matcher)
        self.errors.add(:query, "has unknown matcher : #{matcher}")
        return false
      end
      # validate type of a val
      if type == 'String'
        self.errors.add(:query, "#{key}: #{val.inspect} must be a #{type}") unless val.is_a?(String)
      elsif type == 'Integer' or type == 'Float'
        self.errors.add(:query, "#{key}: #{val.inspect} must be a #{type}") unless val.is_a?(Numeric)
      end
    end
  end

  #convert format from string to selector
  def parameter_sets
    q = ParameterSet.where(simulator: simulator)
    self.query.each do |key,matcher,val|
      h = {}
      type = self.simulator.parameter_definition_for(key).type
      if type == "String"
        h["v.#{key}"] = string_matcher_to_regexp(matcher, val)
      else
        h["v.#{key}"] = (matcher == "eq" ? val : {"$#{matcher}" => val} )
      end
      q = q.where(h)
    end
    q
  end

  def selector
    parameter_sets.selector
  end

  private
  def supported_matchers(type)
    case type
    when "Integer", "Float"
      NumTypeMatchers
    when "String"
      StringTypeMatchers
    else
      raise "not supported type"
    end
  end

  def string_matcher_to_regexp(matcher, value)
    case matcher
    when "start_with"
      /\A#{value}/
    when "end_with"
      /#{value}\z/
    when "include"
      /#{value}/
    when "match"
      /\A#{value}\z/
    else
      raise "not supported matcher : #{matcher}"
    end
  end

  def cast_values
    self.query.each do |a|
      key,matcher,val = a
      defn = simulator.parameter_definition_for(key)
      type = defn.type
      # cast value to the specified type
      casted_val = ParametersUtil.cast_value(val, type)
      self.errors.add(key, "'#{val}' is not valid as a #{type}") if casted_val.nil?
      a[2] = casted_val
    end
  end
end
