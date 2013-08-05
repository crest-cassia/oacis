class Analyzer
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :type, type: Symbol
  field :command, type: String
  field :auto_run, type: Symbol, default: :no
  field :description, type: String

  embeds_many :parameter_definitions
  belongs_to :simulator
  has_many :analyses, dependent: :destroy

  validates :name, presence: true, uniqueness: true, format: {with: /\A\w+\z/}
  validates :type, presence: true, 
                   inclusion: {in: [:on_run, :on_parameter_set, :on_parameter_set_group]}
  validates :command, presence: true
  validates :auto_run, inclusion: {in: [:yes, :no, :first_run_only]}

  accepts_nested_attributes_for :parameter_definitions, allow_destroy: true
  attr_accessible :name, :type, :command, :description, :auto_run, :parameter_definitions_attributes, :simulator

  public
  def parameter_definition_for(key)
    found = self.parameter_definitions.detect do |pd|
      pd.key == key
    end
    found
  end

end
