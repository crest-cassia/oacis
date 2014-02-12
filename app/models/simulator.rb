class Simulator
  include Mongoid::Document
  include Mongoid::Timestamps
  field :name, type: String
  field :command, type: String
  field :description, type: String
  field :support_input_json, type: Boolean, default: false
  field :support_mpi, type: Boolean, default: false
  field :support_omp, type: Boolean, default: false
  field :pre_process_script, type: String
  field :print_version_command, type: String

  embeds_many :parameter_definitions
  has_many :parameter_sets, dependent: :destroy
  has_many :runs
  has_many :parameter_set_queries, dependent: :destroy
  has_many :analyzers, dependent: :destroy
  has_and_belongs_to_many :executable_on, class_name: "Host", inverse_of: :executable_simulators

  validates :name, presence: true, uniqueness: true, format: {with: /\A\w+\z/}
  validate :name_not_changed_after_ps_created
  validates :command, presence: true
  validates :parameter_definitions, presence: true

  accepts_nested_attributes_for :parameter_definitions, allow_destroy: true
  attr_accessible :name, :pre_process_script, :command, :description,
                  :parameter_definitions_attributes, :executable_on_ids,
                  :support_input_json, :support_omp, :support_mpi,
                  :print_version_command

  after_create :create_simulator_dir

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
    aggregated = Run.collection.aggregate(
      { '$match' => Run.where(simulator_id: id).selector },
      { '$group' => {'_id' => '$status', count: { '$sum' => 1}} }
      )
    # aggregated is an Array like [ {"_id" => :created, "count" => 3}, ...]
    counts = Hash[ aggregated.map {|d| [d["_id"], d["count"]] } ]

    # merge default value because some 'counts' do not have keys whose count is zero.
    default = {created: 0, submitted: 0, running: 0, failed: 0, finished: 0, cancelled: 0}
    counts.merge!(default) {|key, self_val, other_val| self_val }
  end

  def parameter_definition_for(key)
    found = self.parameter_definitions.detect do |pd|
      pd.key == key
    end
    found
  end

  def plottable
    run = Run.where(simulator: self, status: :finished).first
    list = plottable_keys(run.try(:result)).map {|key| ".#{key}" }

    analyzers.each do |azr|
      anl = azr.analyses.where(status: :finished).first
      keys = plottable_keys(anl.try(:result)).map do |key|
        "#{azr.name}.#{key}"
      end
      list += keys
    end
    list
  end

  def plottable_domains
    all_domains = {}

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

  private
  def domains(collection_class, query, result_keys)
    group = {_id: 0}
    result_keys.each do |result_key|
      # Because key of the group cannot include '.', substitute '.' with '_'
      group["min_#{result_key.gsub('.', '_')}"] = {'$min' => "$result.#{result_key}" }
      group["max_#{result_key.gsub('.', '_')}"] = {'$max' => "$result.#{result_key}" }
    end

    aggregated = collection_class.collection.aggregate(
      {'$match' =>  query.selector },
      {'$group' => group }
    )
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
    aggregated = ParameterSet.collection.aggregate(
      {'$match' => query.selector },
      {'$group' => group }
    ).first

    ranges = {}
    parameter_definitions.each do |pd|
      ranges[pd.key] = [ aggregated["min-#{pd.key}"], aggregated["max-#{pd.key}"] ]
    end
    ranges
  end

  public
  def progress_overview_data(parameter_key1, parameter_key2)
    parameter_values = [
      parameter_sets.distinct("v.#{parameter_key1}").sort,
      parameter_sets.distinct("v.#{parameter_key2}").sort
    ]

    map = <<-EOS
function() {
  var key = [ this.v["#{parameter_key1}"], this.v["#{parameter_key2}"] ];
  if( this.runs_status_count_cache ) {
    var cache = this.runs_status_count_cache;
    var total_runs = 0;
    for(var stat in cache) {
      if (stat == "cancelled") continue;
      total_runs += cache[stat];
    }
    var val = {finished: cache["finished"], total: total_runs };
    emit(key, val);
  }
  else {
    emit(key, { ids: [this._id]} );
  }
}
EOS

    reduce = <<-EOS
function(key,values) {
  var reduced = {finished: 0, total: 0, ids: []};
  values.forEach( function(v){
    if( v.finished ) { reduced.finished += v.finished; }
    if( v.total ) { reduced.total += v.total; }
    if( v.ids ) { reduced.ids = reduced.ids.concat(v.ids); }
  });
  return reduced;
}
EOS

    parameters_to_runs_count = {}
    parameter_sets.map_reduce(map, reduce).out(inline: true).each do |d|
      # type casting is necessary because numeric data are treated as a Number
      # http://stackoverflow.com/questions/3732161/does-mongodbs-map-reduce-always-return-results-in-floats
      casted_parameters = [parameter_key1, parameter_key2].each_with_index.map do |key,idx|
        type = parameter_definition_for(key).type
        ParametersUtil.cast_value(d["_id"][idx], type)
      end
      runs_count = [ d["value"]["finished"].to_i, d["value"]["total"].to_i ]

      # count for not cached parameter sets
      if d["value"]["ids"].present?
        target_runs = Run.in(parameter_set_id: d["value"]["ids"])
        runs_count[0] += target_runs.where(status: :finished).count
        runs_count[1] += target_runs.ne(status: :cancelled).count
      end

      parameters_to_runs_count[ casted_parameters ] = runs_count
    end

    num_runs = parameter_values[1].map do |p2|
      parameter_values[0].map do |p1|
        parameters_to_runs_count[ [p1,p2] ] or [0, 0]
      end
    end

    progress_overview = {
      parameters: [parameter_key1, parameter_key2],
      parameter_values: parameter_values,
      num_runs: num_runs
    }
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

  def name_not_changed_after_ps_created
    if self.persisted? and self.parameter_sets.any? and self.name_changed?
      errors.add(:name, "is not editable when a parameter set exists")
    end
  end
end
