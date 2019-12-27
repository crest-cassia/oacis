class Simulator
  include Mongoid::Document
  include Mongoid::Timestamps
  include Executable

  field :name, type: String
  field :description, type: String
  field :sequential_seed, type: Boolean, default: false
  field :position, type: Integer # position in the table. start from zero
  field :to_be_destroyed, type: Boolean, default: false
  embeds_many :parameter_definitions
  has_many :parameter_sets, dependent: :destroy
  has_many :runs
  has_many :parameter_set_filters, dependent: :destroy
  has_many :analyzers, dependent: :destroy, autosave: true #enable autosave to copy analyzers
  has_many :save_tasks, dependent: :destroy

  belongs_to :webhook

  default_scope ->{ where(to_be_destroyed: false) }

  validates :name, presence: true, uniqueness: {scope: :to_be_destroyed}, format: {with: /\A\w+\z/}, unless: :to_be_destroyed
  validates :parameter_definitions, presence: true

  accepts_nested_attributes_for :parameter_definitions, allow_destroy: true

  before_create :set_position
  after_create :create_simulator_dir
  before_destroy :delete_simulator_dir

  public
  def dir
    ResultDirectory.simulator_path(self)
  end

  def analyzers_on_run
    self.analyzers.where(type: :on_run)
  end

  def analyzers_on_parameter_set
    self.analyzers.where(type: :on_parameter_set)
  end

  def params_key_count
    counts = {}
    parameter_definitions.each do |pd|
      key = pd.key
      kinds = parameter_sets.only("v").distinct("v."+key)
      counts[key] = []
      kinds.each do |k|
        counts[key] << {k.to_s => parameter_sets.only("v").where("v."+key => k).count}
      end
    end
    counts
  end

  def runs_status_count
    # use aggregate function of MongoDB.
    # See http://blog.joshsoftware.com/2013/09/05/mongoid-and-the-mongodb-aggregation-framework/
    aggregated = Run.collection.aggregate([
      { '$match' => Run.where(simulator_id: id).selector },
      { '$group' => {'_id' => '$status', count: { '$sum' => 1}} }
      ])
    # aggregated is an Array like [ {"_id" => :created, "count" => 3}, ...]
    counts = Hash[ aggregated.map {|d| [d["_id"], d["count"]] } ]

    # merge default value because some 'counts' do not have keys whose count is zero.
    default = {created: 0, submitted: 0, running: 0, failed: 0, finished: 0}
    counts.merge!(default) {|key, self_val, other_val| self_val }
  end

  def parameter_definition_for(key)
    found = self.parameter_definitions.detect do |pd|
      pd.key == key
    end
    found
  end

  def plottable
    list = ["cpu_time", "real_time"]
    run = Run.where(simulator: self, status: :finished).order_by(updated_at: :asc).last
    list += plottable_keys(run.try(:result)).map {|key| ".#{key}" }

    analyzers.each do |azr|
      anl = azr.analyses.where(status: :finished).order_by(updated_at: :asc).last
      keys = plottable_keys(anl.try(:result)).map do |key|
        "#{azr.name}.#{key}"
      end
      list += keys
    end
    list
  end

  def plottable_domains
    all_domains = {}

    # get domains for elapsed times
    all_domains["cpu_time"] = [0.0, Run.where(simulator: self, status: :finished).max(:cpu_time)]
    all_domains["real_time"] = [0.0, Run.where(simulator: self, status: :finished).max(:real_time)]

    # get domains for runs
    first_run = Run.where(simulator: self, status: :finished).first
    run_result_keys = plottable_keys( first_run.try(:result) )
    collection_class = Run
    query = Run.where(simulator: self)
    run_domains = domains(collection_class, query, run_result_keys)
    all_domains.update( Hash[ run_domains.map {|key,val| [".#{key}", val] } ] )

    # get domains for analyses
    analyzers.each do |azr|
      keys = plottable_keys(azr.analyses.where(status: :finished).first.try(:result))
      collection_class = Analysis
      query = Analysis.where(analyzer: azr)
      anl_domains = domains(collection_class, query, keys)
      mapped = anl_domains.map {|key,val| ["#{azr.name}.#{key}", val] }
      all_domains.update( Hash[mapped] )
    end

    all_domains
  end

  def figure_files
    figures_filenames = "*.{png,Png,PNG,jpg,Jpg,JPG,jpeg,Jpeg,JPEG,bmp,Bmp,BMP,gif,Gif,GIF,svg,Svg,SVG}"
    run = runs.where(status: :finished).order_by(:updated_at.desc).first
    list = []
    if run
      list += Dir.glob( run.dir.join(figures_filenames) ).map {|f| "/#{File.basename(f)}" }.uniq
    end

    analyzers.each do |azr|
      next unless azr.analyses
      anl = azr.analyses.where(status: :finished).first
      if anl
        list += Dir.glob( anl.dir.join(figures_filenames) ).map do |f|
          "#{azr.name}/#{File.basename(f)}"
        end.uniq
      end
    end
    list
  end

  # used by APIs
  def self.find_by_name( sim_name )
    found = self.where(name: sim_name).first
    raise "Simulator #{sim_name} is not found" unless found
    found
  end

  def find_parameter_set( parameters )
    given_keys = parameters.keys.map(&:to_s)
    expected_keys = default_parameters.keys
    unknown_keys = given_keys - expected_keys
    raise "Unknown keys: #{unknown_keys}" unless unknown_keys.empty?
    missing_keys = expected_keys - given_keys
    raise "Missing keys: #{missing_keys}" unless missing_keys.empty?

    query = parameters.map {|k,v| ["v.#{k}", v] }.to_h
    parameter_sets.where( query ).first
  end

  def find_or_create_parameter_set( parameters )
    find_parameter_set( parameters ) or parameter_sets.create!(v: parameters)
  end

  def default_parameters
    default = {}
    parameter_definitions.each do |pd|
      default[pd.key] = pd.default
    end
    default.with_indifferent_access
  end

  def find_analyzer_by_name( azr_name )
    found = self.analyzers.where(name: azr_name).first
    raise "Analyzer #{azr_name} is not found" unless found
    found
  end

  def discard
    update_attribute(:to_be_destroyed, true)
    set_lower_submittable_to_be_destroyed
  end

  def destroyable?
    if runs.unscoped.empty?
      azr_ids = analyzers.unscoped.map {|azr| azr.id }
      Analysis.unscoped.where(:analyzer_id.in => azr_ids).empty?
    else
      false
    end
  end

  def set_lower_submittable_to_be_destroyed
    runs.update_all(to_be_destroyed: true)
    azr_ids = analyzers.unscoped.map {|azr| azr.id }
    Analysis.where(:analyzer_id.in => azr_ids).update_all(to_be_destroyed: true)
    reload
  end

  private
  def domains(collection_class, query, result_keys)
    group = {_id: 0}
    result_keys.each do |result_key|
      # Because key of the group cannot include '.', substitute '.' with '_'
      group["min_#{result_key.gsub('.', '_')}"] = {'$min' => "$result.#{result_key}" }
      group["max_#{result_key.gsub('.', '_')}"] = {'$max' => "$result.#{result_key}" }
    end

    aggregated = collection_class.collection.aggregate([
      {'$match' =>  query.selector },
      {'$group' => group }
    ])
    aggregated = aggregated.first

    ranges = {}
    result_keys.each do |result_key|
      ranges["#{result_key}"] = [aggregated["min_#{result_key.gsub('.', '_')}"],
                                 aggregated["max_#{result_key.gsub('.', '_')}"] ]
    end
    ranges
  end

  public
  def parameter_ranges
    query = ParameterSet.where(simulator: self)
    group = {_id: 0}
    parameter_definitions.each do |pd|
      next unless pd.type == "Float" or pd.type == "Integer"
      # pd.key cannot include '-'. Hence, prefix "min-" and "max-" are safe.
      group["min-#{pd.key}"] = { '$min' => "$v.#{pd.key}" }
      group["max-#{pd.key}"] = { '$max' => "$v.#{pd.key}" }
    end
    aggregated = ParameterSet.collection.aggregate([
      {'$match' => query.selector },
      {'$group' => group }
    ]).first

    ranges = {}
    parameter_definitions.each do |pd|
      ranges[pd.key] = [ aggregated["min-#{pd.key}"], aggregated["max-#{pd.key}"] ]
    end
    ranges
  end

  public
  def progress_overview_data(parameter_key1, parameter_key2)
    aggregated = Run.collection.aggregate([
        { '$match'  => Run.where(simulator_id: self.id).selector },
        { '$lookup' => { from: 'parameter_sets', localField: 'parameter_set_id', foreignField: '_id', as: 'ps' }},
        { '$unwind' => '$ps'},
        { '$group'  =>
              {
                  '_id' => {'x' => "$ps.v.#{parameter_key1}", 'y' => "$ps.v.#{parameter_key2}", 'status' => "$status"},
                  'count' => { '$sum' => 1}
              }
        }
    ])

    x_keys = []
    y_keys = []
    counts = {}
    aggregated.each do |doc|
      x = doc['_id']['x']
      y = doc['_id']['y']
      status = doc['_id']['status']
      x_keys << x
      y_keys << y
      k = [x,y,:total]
      counts[k] = counts[k].to_i + doc['count']
      if status == :finished
        k = [x,y,:finished]
        counts[k] = counts[k].to_i + doc['count']
      end
    end

    [x_keys, y_keys].each {|k| k.uniq!; k.sort! }

    num_runs = y_keys.map do |y|
      x_keys.map do |x|
        [ counts[[x,y,:finished]].to_i, counts[[x,y,:total]].to_i ]
      end
    end

    progress_overview = {
      parameters: [parameter_key1, parameter_key2],
      parameter_values: [x_keys, y_keys],
      num_runs: num_runs
    }
  end

  def num_ps_and_runs_being_created
    tasks = save_tasks.where(cancel_flag: false)
    num_ps = tasks.inject(0) {|sum,t| sum + t.creation_size }
    num_runs = tasks.inject(0) {|sum,t| sum + t.creation_size * t.num_runs}
    [num_ps,num_runs]
  end

  private
  def plottable_keys(result)
    ret = []
    if result.is_a?(Hash)
      result.each_pair do |key, val|
        if val.is_a?(Numeric)
          ret << key
        elsif val.is_a?(Hash)
          ret += plottable_keys(val).map {|x| "#{key}.#{x}" }
        end
      end
    end
    ret
  end

  def create_simulator_dir
    FileUtils.mkdir_p(ResultDirectory.simulator_path(self))
  end

  def delete_simulator_dir
    FileUtils.rm_r(dir) if Dir.exists?(dir)
  end

  private
  def set_position
    self.position = Simulator.count
  end

  public
  def simulator_versions
    # Output should look like follows
    # [{"_id"=>"v1",
    #   "oldest_started_at"=>2014-04-19 02:10:08 UTC,
    #   "latest_started_at"=>2014-04-20 02:10:08 UTC,
    #   "count" => {:finished => 2} },
    #  {"_id"=>"v2",
    #   "oldest_started_at"=>2014-04-19 02:10:08 UTC,
    #   "latest_started_at"=>2014-04-21 02:10:08 UTC,
    #   "count"=> {:finished => 2, :failed => 1} }]
    query = Run.where(simulator: self).exists(started_at: true)
    aggregated = Run.collection.aggregate([
      {'$match' => query.selector },
      { '$group' => {'_id' => { version: '$simulator_version', status: '$status'},
                     oldest_started_at: { '$min' => '$started_at'},
                     latest_started_at: { '$max' => '$started_at'},
                     count: {'$sum' => 1}
                     }}
    ])

    sim_versions = {}
    aggregated.each do |h|
      version = h['_id']['version']
      merged = (sim_versions[version] or {})
      if merged['oldest_started_at'].nil? or merged['oldest_started_at'] > h['oldest_started_at']
        merged['oldest_started_at'] = h['oldest_started_at']
      end
      if merged['latest_started_at'].nil? or merged['latest_started_at'] < h['latest_started_at']
        merged['latest_started_at'] = h['latest_started_at']
      end
      merged['count'] ||= {}
      status = h['_id']['status']
      merged['count'][status] = h['count']
      sim_versions[version] = merged
    end

    sim_versions.map {|key,val| val['version'] = key; val }.sort_by {|a| a['latest_started_at']}
  end

  require 'csv'
  def runs_csv(runs = self.runs)
    run_attr = %w(_id status hostname real_time started_at finished_at seed)
    ps_attr = [[:ps,:_id]] + parameter_definitions.map {|pd| [:ps,:v,pd.key] }
    ps_attr_header = ["ps_id"] + parameter_definitions.map {|pd| "p.#{pd.key}" }
    latest_run = Run.where(simulator: self, status: :finished).order_by(updated_at: :desc).first
    result_attr_header = plottable_keys(latest_run&.result).map {|key| "r.#{key}" }
    result_attr = plottable_keys(latest_run&.result).map {|key| [:result]+key.split('.') }
    attr = run_attr + ps_attr + result_attr
    header = run_attr + ps_attr_header + result_attr_header
    header[0] = 'run_id'

    aggregated = Run.collection.aggregate([
      { '$match'  => runs.selector },
      { '$lookup' => { from: 'parameter_sets', localField: 'parameter_set_id', foreignField: '_id', as: 'ps' }},
      { '$unwind' => '$ps'}
    ])

    CSV.generate(headers: header, write_headers: true) do |csv|
      aggregated.each do |r|
        csv << attr.map {|keys| r.dig(*keys)}
      end
    end
  end
end
