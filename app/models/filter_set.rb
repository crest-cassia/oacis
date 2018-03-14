class FilterSet
  include Mongoid::Document

  field :name, type: String
  belongs_to :simulator
  has_many :parameter_set_filters, dependent: :destroy
  validates :simulator, presence: true
  validates :name, presence: true
  validate :validate_uniqueness_of_name

  def validate_uniqueness_of_name
    if self.name.blank?
      self.errors.add(:name, "must not be blank")
      return
    end

    if FilterSet.where(simulator: simulator, name: name).count > 0
      self.errors.add(:name, "must be unique")
    end
  end

  def set_filters(settings)
    return false if settings.blank?

    settings.each do |para|
      self.parameter_set_filters.build
      self.parameter_set_filters.set_filter(para)
    end
  end

  #convert format from string to selector
  def parameter_sets
    q = ParameterSet.where(simulator: simulator)
    self.parameter_set_filters.each do |filter|
      a = []
      next unless filter.enable
      filter.query.each do |key, criteria|
        h = {}
        pd = self.simulator.parameter_definition_for(key)
        type = pd.type
        criteria.each do |matcher,value|
          unless supported_matchers(type).include?(matcher)
            raise "undefined matcher #{matcher} for #{type}"
          end
          if type == "String"
            h["v.#{key}"] = string_matcher_to_regexp(matcher, value)
          else
            h["v.#{key}"] = (matcher == "eq" ? value : {"$#{matcher}" => value} )
          end
        end
        Rails.logger.debug "Where: " + h.to_s
        q = q.where(h)
      end
    end
    return q
  end

  def selector
    parameter_sets.selector
  end

  private
  def supported_matchers(type)
    supported_matchers = []
    case type
    when "Integer", "Float"
      supported_matchers = ParameterSetFilter.getNumTypeMatchers()
    when "Boolean"
      supported_matchers = ParameterSetFilter.BooleanTypeMatchers()
    when "String"
      supported_matchers = ParameterSetFilter.StringTypeMatchers()
    else
      raise "not supported type"
    end
    return supported_matchers
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

end
