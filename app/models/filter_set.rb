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

end
