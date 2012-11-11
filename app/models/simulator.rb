class Simulator
  include Mongoid::Document
  include Mongoid::Timestamps
  field :name, type: String
  field :parameter_keys, type: Hash
  # field :run_parameter_keys, type: Hash
  field :execution_command, type: String
  # field :comments, type: String
  # embeds_many :analysis_methods
  # embeds_many :simulator_admin_users
  # embeds_many :editable_users
  # embeds_many :readable_users

  validates :name, presence: true, uniqueness: true, format: {with: /\A\w+\z/}
  validate :parameter_keys_format
  
  private
  def parameter_keys_format
    unless parameter_keys.size > 0
      errors.add(:parameter_keys, "parameter keys cannot be empty")
      return
    end
    parameter_keys.each do |key, value|
      unless key =~ /\A\w+\z/
        errors.add(:parameter_keys, "parameter key name must match '/\A\w+\z/'")
        break
      end
      unless value.has_key?("type")
        errors.add(:parameter_keys, "each parameter key must has a type")
        break
      end
      unless ["Boolean","Integer","Float","String"].include?(value["type"])
        errors.add(:parameter_keys, "type of each parameter must either 'Boolean', 'Integer', 'Float', or 'String'")
        break
      end
    end
  end
    
end
