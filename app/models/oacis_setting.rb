class OacisSetting
  include Mongoid::Document
  include Mongoid::Timestamps::Created

  field :notification_level, type: Integer, default: 1
  field :webhook_url, type: String
  field :oacis_url, type: String

  validates :notification_level, inclusion: 1..3
  validate :only_one_row, on: :create

  def self.instance
    first_or_create!
  end

  private

  def only_one_row
    errors.add(:base, 'OacisSetting already exists.') if OacisSetting.exists?
  end
end
