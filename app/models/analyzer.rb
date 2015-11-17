class Analyzer
  include Mongoid::Document
  include Mongoid::Timestamps
  include Executable

  field :name, type: String
  field :type, type: Symbol
  field :auto_run, type: Symbol, default: :no
  field :description, type: String
  field :to_be_destroyed, type: Boolean, default: false

  embeds_many :parameter_definitions
  belongs_to :simulator
  has_many :analyses

  ## fields for auto run
  belongs_to :auto_run_submitted_to, class_name: "Host"

  default_scope ->{ where(:to_be_destroyed.in => [nil,false]) }

  validates :name, presence: true, uniqueness: {scope: :simulator}, format: {with: /\A\w+\z/}
  validates :type, presence: true, 
                   inclusion: {in: [:on_run, :on_parameter_set]}
  validates :auto_run, inclusion: {in: [:yes, :no, :first_run_only]}
  validate :auto_run_submitted_to_is_in_executable_on

  accepts_nested_attributes_for :parameter_definitions, allow_destroy: true

  public
  def parameter_definition_for(key)
    found = self.parameter_definitions.detect do |pd|
      pd.key == key
    end
    found
  end

  public
  def analyzer_versions
    # output should look like follows
    # [{"_id"=>"v1",
    #   "oldest_started_at"=>2014-04-19 02:10:08 utc,
    #   "latest_started_at"=>2014-04-20 02:10:08 utc,
    #   "count" => {:finished => 2} },
    #  {"_id"=>"v2",
    #   "oldest_started_at"=>2014-04-19 02:10:08 utc,
    #   "latest_started_at"=>2014-04-21 02:10:08 utc,
    #   "count"=> {:finished => 2, :failed => 1} }]
    query = Analysis.where(analyzer: self).exists(started_at: true).selector
    aggregated = Analysis.collection.aggregate(
      {'$match' => query },
      { '$group' => {'_id' => { version: '$analyzer_version', status: '$status'},
                     oldest_started_at: { '$min' => '$started_at'},
                     latest_started_at: { '$max' => '$started_at'},
                     count: {'$sum' => 1}
                     }})

    anl_versions = {}
    aggregated.each do |h|
      version = h['_id']['version']
      merged = (anl_versions[version] or {})
      if merged['oldest_started_at'].nil? or merged['oldest_started_at'] > h['oldest_started_at']
        merged['oldest_started_at'] = h['oldest_started_at']
      end
      if merged['latest_started_at'].nil? or merged['latest_started_at'] < h['latest_started_at']
        merged['latest_started_at'] = h['latest_started_at']
      end
      merged['count'] ||= {}
      status = h['_id']['status']
      merged['count'][status] = h['count']
      anl_versions[version] = merged
    end

    anl_versions.map {|key,val| val['version'] = key; val }.sort_by {|a| a['latest_started_at']}
  end

  def destroyable?
    analyses.unscoped.empty?
  end

  def set_lower_submittable_to_be_destroyed
    analyses.update_all(to_be_destroyed: true)
  end

  private
  def auto_run_submitted_to_is_in_executable_on
    return if auto_run_submitted_to.blank?
    unless executable_on.where(id: auto_run_submitted_to).first
       errors.add(:auto_run_submitted_to, "is not included in executable hosts")
    end
  end
end
