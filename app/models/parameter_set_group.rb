class ParameterSetGroup
  include Mongoid::Document
  include Mongoid::Timestamps

  belongs_to :simulator
  has_and_belongs_to_many :parameter_sets
  embeds_many :analysis_runs, as: :analyzable

  after_save :create_dir

  public
  def dir
    ResultDirectory.parameter_set_group_path(self)
  end

  def create_dir
    FileUtils.mkdir_p(self.dir)
  end
end
