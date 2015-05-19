class ParameterSet
  include Mongoid::Document
  include Mongoid::Timestamps
  field :v, type: Hash
  field :runs_status_count_cache, type: Hash
  field :progress_rate_cache, type: Integer # used for sorting by progress. updated at the same time with the run_status_count_cache
  index({ v: 1 }, { name: "v_index" })
  belongs_to :simulator, autosave: false
  has_many :runs, dependent: :destroy
  has_many :analyses, as: :analyzable, dependent: :destroy

  validates :simulator, :presence => true
  validate :cast_and_validate_parameter_values, on: :create

  after_create :create_parameter_set_dir
  before_destroy :delete_parameter_set_dir

  public
  def dir
    ResultDirectory.parameter_set_path(self)
  end

  def parameter_sets_with_different(key, irrelevant_keys = [])
    query_param = { simulator: self.simulator }
    v.each_pair do |prm_key,prm_val|
      next if prm_key == key.to_s or irrelevant_keys.include?(prm_key)
      query_param["v.#{prm_key}"] = prm_val
    end
    self.class.where(query_param).asc("v.#{key}")
  end

  def parameter_keys_having_distinct_values
    simulator.parameter_definitions.map(&:key).select do |key|
      parameter_sets_with_different(key).count > 1
    end
  end

  def runs_status_count
    # I do not know why but reload is necessary. Otherwise, _cache is always nil.
    reload
    if runs_status_count_cache
      update_progress_rate_cache unless progress_rate_cache
      return Hash[ runs_status_count_cache.map {|key,val| [key.to_sym, val]} ]
    end

    # use aggregate function of MongoDB.
    # See http://blog.joshsoftware.com/2013/09/05/mongoid-and-the-mongodb-aggregation-framework/
    aggregated = Run.collection.aggregate(
      { '$match' => Run.where(parameter_set_id: id).selector },
      { '$group' => {'_id' => '$status', count: { '$sum' => 1}} }
      )
    # aggregated is an Array like [ {"_id" => :created, "count" => 3}, ...]
    counts = Hash[ aggregated.map {|d| [d["_id"], d["count"]] } ]

    # merge default value because some 'counts' do not have keys whose count is zero.
    default = {created: 0, submitted: 0, running: 0, failed: 0, finished: 0, cancelled: 0}
    counts.merge!(default) {|key, self_val, other_val| self_val }

    # skip validation using update_attribute method in order to improve performance
    # disable automatic time-stamp update when updating cache
    # See http://mongoid.org/en/mongoid/docs/extras.html#timestamps
    timeless.update_attribute(:runs_status_count_cache, counts)

    update_progress_rate_cache

    counts
  end

  private
  def cast_and_validate_parameter_values
    unless v.is_a?(Hash)
      errors.add(:v, "v is not a Hash")
      return
    end

    return unless self.simulator # presence of simulator is checked by another validator

    # cast parameter values
    defn = self.simulator.parameter_definitions
    casted = ParametersUtil.cast_parameter_values(v, defn, errors)
    if errors.any?
      return
    end
    self.v = casted

    found = self.class.find_identical_parameter_set(simulator, v)
    if found and found.id != self.id
      errors.add(:parameters, "An identical parameters already exists : #{found.to_param}")
      return
    end
  end

  def self.find_identical_parameter_set(simulator, sim_param_hash)
    self.where(:simulator => simulator, :v => sim_param_hash).first
  end

  def create_parameter_set_dir
    FileUtils.mkdir_p(ResultDirectory.parameter_set_path(self))
  end

  def delete_parameter_set_dir
    # if self.simulator.nil, parent Simulator is already destroyed.
    # Therefore, self.dir raises an exception
    if self.simulator and File.directory?(self.dir)
      FileUtils.rm_r(self.dir)
    end
  end

  def update_progress_rate_cache
    # make it negative in order to show all-finished-ps on top when sorted in ascending order
    counts = Hash[ runs_status_count_cache.map {|key,val| [key.to_sym, val]} ]
    total = counts.inject(0) {|sum, v| sum += v[1]}
    rate = 0
    rate = - (counts[:finished]*1000000/total).to_i - (counts[:failed]*10000/total).to_i - (counts[:running]*100/total).to_i  if total > 0
    timeless.update_attribute(:progress_rate_cache, rate)
  end
end
