class Analyzer
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :type, type: Symbol
  field :parameter_definitions, type: Hash
  field :command, type: String
  field :auto_run, type: Symbol, default: :no
  field :description, type: String

  embedded_in :simulator

  validates :name, presence: true, uniqueness: true, format: {with: /\A\w+\z/}
  validates :type, presence: true, 
                   inclusion: {in: [:on_run, :on_parameter_set, :on_parameter_set_group]}
  validates :command, presence: true
  validates :auto_run, inclusion: {in: [:yes, :no, :first_run_only]}
  validate :parameter_definitions_format

  private
  def parameter_definitions_format
    self.parameter_definitions = {} if parameter_definitions.nil?
    parameter_definitions.each do |key, value|
      unless key =~ /\A\w+\z/
        errors.add(:parameter_definitions, "parameter name must match '/\A\w+\z/'")
        break
      end
      unless value.has_key?("type")
        errors.add(:parameter_definitions, "each parameter must has a type")
        break
      end
      unless ["Boolean","Integer","Float","String"].include?(value["type"])
        errors.add(:parameter_definitions, "type of each parameter must either 'Boolean', 'Integer', 'Float', or 'String'")
        break
      end
    end
  end
end
