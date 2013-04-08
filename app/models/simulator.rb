class Simulator
  include Mongoid::Document
  include Mongoid::Timestamps
  field :name, type: String
  field :parameter_keys, type: Hash
  field :execution_command, type: String

  validates :name, presence: true, uniqueness: true, format: {with: /\A\w+\z/}
  validates :execution_command, presence: true
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
