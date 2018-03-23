class ParameterSet
  include Mongoid::Document
  include Mongoid::Timestamps
  field :v, type: Hash
  field :to_be_destroyed, type: Boolean, default: false
  index({ simulator_id: 1, v: 1 })
  index({ simulator_id: 1, updated_at: -1 })
  belongs_to :simulator, autosave: false, index: true
  has_many :runs
  has_many :analyses, as: :analyzable

  default_scope ->{ where(:to_be_destroyed.in => [nil,false]) }

  validates :simulator, :presence => true
  validate :cast_parameter_values, on: :create
  validate :validate_parameter_values, on: :create, unless: :skip_check_uniquness

  after_create :create_parameter_set_dir
  before_destroy :delete_parameter_set_dir

  attr_accessor :skip_check_uniquness

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

  def self.runs_status_count_batch( parameter_sets )
    aggregated = Run.collection.aggregate([
      {
        '$match' => Run.in(parameter_set: parameter_sets.map(&:id)).selector
      },
      {
        '$group' => {
          '_id' => {'psid'=>'$parameter_set_id', 'status'=>'$status'},
          'count' => { '$sum' => 1}
        }
      },
      {
        '$group' => {
          '_id' => '$_id.psid',
          'counts' => {
            '$push' =>{'status'=>'$_id.status', 'count'=> '$count' }
          }
        }
      }
    ])
    # aggregated is
    # [
    #   { _id => psid, "counts" => [{status => count} .... ],
    #   ...
    # ]
    count_default = {created: 0, submitted: 0, running: 0, failed: 0, finished: 0}
    ret = {}
    parameter_sets.each {|ps| ret[ps.id] = count_default.dup }

    aggregated.each do |doc|
      psid = doc["_id"]
      status_hash = count_default.dup
      doc["counts"].each do |c|
        key = c["status"]
        status_hash[key] = c["count"]
      end
      ret[ psid ] = status_hash
    end
    ret
  end

  # public APIs
  def find_or_create_runs_upto( num_runs, submitted_to: nil, host_param: nil, host_group: nil, mpi_procs: 1, omp_threads: 1, priority: 1)
    found = runs.asc(:created_at).limit(num_runs).to_a
    n = found.size

    params = { mpi_procs: mpi_procs, omp_threads: omp_threads, priority: priority }
    if num_runs > n
      if host_group
        raise "You can set either submitted_to or host_group" if submitted_to
        params[:host_group] = host_group
      else
        host_param ||= submitted_to.try(:default_host_parameters)
        params.merge!( submitted_to: submitted_to, host_parameters: host_param )
      end
      (num_runs - n).times do |i|
        r = runs.create!( params )
        found << r
      end
    end
    found
  end

  def average_result(key, error: false)
    results = runs.where(status: :finished).only(:result).map {|r| r.result[key].to_f }.compact
    n = results.size
    return ( error ? [nil,0,nil] : [nil,0] ) if n==0
    avg = results.inject(:+) / n
    if error
      r2_sum = results.inject(0.0) {|sum,x| sum + (x-avg)**2}
      err = n > 1 ? Math.sqrt(r2_sum/(n*(n-1.0))) : nil
      return [avg, n, err]
    else
      return [avg, n]
    end
  end

  def discard
    update_attribute(:to_be_destroyed, true)
    set_lower_submittable_to_be_destroyed
  end

  def destroyable?
    if runs.unscoped.empty? and analyses.unscoped.empty?
      run_ids = runs.unscoped.map {|run| run.id }
      Analysis.unscoped.where(:analyzable_id.in => run_ids).empty?
    else
      false
    end
  end

  def set_lower_submittable_to_be_destroyed
    runs.update_all(to_be_destroyed: true)
    analyses.update_all(to_be_destroyed: true)
    run_ids = runs.unscoped.map {|run| run.id }
    Analysis.where(:analyzable_id.in => run_ids).update_all(to_be_destroyed: true)
    reload
  end

  private
  def cast_parameter_values
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
  end

  def validate_parameter_values
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
end
