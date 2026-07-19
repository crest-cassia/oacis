class ParameterSet
  include Mongoid::Document
  include Mongoid::Timestamps

  field :v, type: Hash
  field :fingerprint, type: String
  field :to_be_destroyed, type: Mongoid::Boolean, default: false
  index({ simulator_id: 1, v: 1 })
  index({ simulator_id: 1, updated_at: -1 })
  # Uniqueness of parameter values is guaranteed at the DB level via a digest
  # of the normalized values. Partial index: documents whose fingerprint is
  # unset (discarded PS, or data created before the backfill script has run)
  # are exempt from the constraint.
  index({ simulator_id: 1, fingerprint: 1 },
        { unique: true, partial_filter_expression: { fingerprint: { '$exists' => true } } })
  belongs_to :simulator, autosave: false, index: true, touch: true
  has_many :runs
  has_many :analyses, as: :analyzable

  default_scope ->{ where(:to_be_destroyed.in => [nil,false]) }

  validates :simulator, :presence => true
  validate :cast_parameter_values, on: :create
  validate :validate_parameter_values, on: :create, unless: :skip_check_uniqueness

  before_create :set_fingerprint
  before_update :refresh_fingerprint
  after_create :create_parameter_set_dir
  before_destroy :delete_parameter_set_dir

  attr_accessor :skip_check_uniqueness

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
    # Release the fingerprint so that an identical PS can be created again
    # while this one is waiting for actual destruction by the worker.
    unset(:fingerprint)
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

  # digest of the parameter values, insensitive to the key order of (nested) hashes
  def self.fingerprint_of(param_hash)
    Digest::SHA256.hexdigest( canonical_json(param_hash) )
  end

  def self.canonical_json(value)
    case value
    when Hash
      "{" + value.map {|k,val| [k.to_s, val] }.sort_by {|k,_| k }
                 .map {|k,val| "#{k.to_json}:#{canonical_json(val)}" }.join(",") + "}"
    when Array
      "[" + value.map {|x| canonical_json(x) }.join(",") + "]"
    else
      value.to_json
    end
  end

  def self.duplicate_key_error?(exception)
    exception.is_a?(Mongo::Error::OperationFailure) and
      ( exception.code == 11000 or exception.message.include?("E11000") )
  end

  # Atomically find or create a ParameterSet for the given parameters.
  # Concurrent creation of an identical PS is prevented by the unique index
  # on (simulator_id, fingerprint); when the insert loses the race, the PS
  # created by the winner is returned.
  # Returns [parameter_set, created].
  def self.find_or_create!(simulator, parameters)
    casted = ParametersUtil.cast_parameter_values(parameters, simulator.parameter_definitions)
    if casted.nil?
      # let the validation report the cast error
      return [simulator.parameter_sets.create!(v: parameters), true]
    end
    found = find_by_casted_values(simulator, casted)
    return [found, false] if found
    begin
      ps = simulator.parameter_sets.create!(v: casted, skip_check_uniqueness: true)
      [ps, true]
    rescue Mongo::Error::OperationFailure => ex
      raise unless duplicate_key_error?(ex)
      found = find_by_casted_values(simulator, casted)
      raise unless found
      [found, false]
    end
  end

  def self.find_by_casted_values(simulator, casted)
    query = casted.map {|key,val| ["v.#{key}", val] }.to_h
    simulator.parameter_sets.where(query).first ||
      simulator.parameter_sets.where(fingerprint: fingerprint_of(casted)).first
  end

  def set_fingerprint
    self.fingerprint = self.class.fingerprint_of(v) if v.is_a?(Hash)
  end

  # Keep the fingerprint consistent when v is modified after creation
  # (e.g. `oacis_cli append_parameter_definition` adds a key to every PS).
  # PSs whose fingerprint has been removed on purpose (discarded ones, or
  # duplicates exempted by db:update_schema) must stay out of the unique
  # index, so they are left untouched.
  def refresh_fingerprint
    if v_changed? and fingerprint.present?
      self.fingerprint = self.class.fingerprint_of(v)
    end
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
