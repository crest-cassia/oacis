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
  # after_create_commit (not after_create): creation runs inside a
  # transaction which may be retried or aborted; the directory must be
  # created only once the insert is actually committed
  after_create_commit :create_parameter_set_dir
  before_destroy :delete_parameter_set_dir

  attr_accessor :skip_check_uniqueness

  public
  # Creation runs inside a multi-document transaction so that v is always
  # casted against the current parameter definitions even when they are
  # being changed concurrently (append_parameter_definition):
  # - The simulator document is WRITTEN first. MongoDB transactions detect
  #   write-write conflicts only (snapshot isolation, no write-skew
  #   protection), so a mere read of the definitions would NOT conflict
  #   with a concurrent definitions change. The write makes the two
  #   operations mutually exclusive: the loser aborts and is retried by
  #   the driver against a fresh snapshot.
  # - The simulator is then reloaded inside the transaction snapshot, so
  #   the cast validator uses definitions that are guaranteed current at
  #   commit time.
  def save(options = {})
    return super unless new_record? and simulator_id
    return super if self.class.inside_transaction?
    first_attempt = true
    self.class.transaction do
      unless first_attempt
        # the previous attempt was rolled back but left this document
        # flagged as persisted; without re-arming, the retry would take
        # the update path and silently insert nothing
        self.new_record = true
      end
      first_attempt = false
      Simulator.where(id: simulator_id).find_one_and_update('$currentDate' => { updated_at: true })
      simulator.reload if simulator
      super
    end
  end

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
    # validations do not halt the chain: when the cast failed, v is not in
    # canonical form and must not be matched against
    return if errors.any?
    # read-only lookup: this validator runs inside the creation
    # transaction, so any migration written here would be rolled back on
    # a validation failure. Legacy migration lives in find_or_create!.
    found = self.class.find_by_casted_values(simulator, v)
    if found and found.id != self.id
      errors.add(:parameters, "An identical parameters already exists : #{found.to_param}")
      return
    end
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

  def self.inside_transaction?
    session = Mongoid::Threaded.get_session(client: collection.client)
    !!(session && session.in_transaction?)
  end

  # Atomically find or create a ParameterSet for the given parameters.
  # Concurrent creation of an identical PS is prevented by the unique index
  # on (simulator_id, fingerprint); when the insert loses the race, the PS
  # created by the winner is returned. A concurrent change of the parameter
  # definitions is handled by the transaction inside ParameterSet#save.
  # Returns [parameter_set, created].
  def self.find_or_create!(simulator, parameters)
    # operate on fresh definitions; the given instance may be long-lived
    simulator.reload
    casted = ParametersUtil.cast_parameter_values(parameters, simulator.parameter_definitions)
    if casted.nil?
      # let the validation report the cast error
      return [simulator.parameter_sets.create!(v: parameters), true]
    end
    MAX_LEGACY_MIGRATION_RETRY.times do
      found = find_by_casted_values(simulator, casted)
      if found
        return [found, false] if (casted.keys - found.v.keys).empty?
        # a legacy PS not yet migrated after append_parameter_definition:
        # bring it up to date instead of creating a duplicate
        migrated = migrate_legacy!(found, casted_defaults_of(simulator))
        return [migrated, false] if migrated
        next # the PS changed underneath (filled or discarded); redo the lookup
      end
      begin
        ps = simulator.parameter_sets.create!(v: casted, skip_check_uniqueness: true)
        return [ps, true]
      rescue Mongo::Error::OperationFailure => ex
        raise unless duplicate_key_error?(ex)
        # the definitions may have changed while we were trying to insert;
        # re-cast before looking up the winner
        recasted = ParametersUtil.cast_parameter_values(parameters, simulator.reload.parameter_definitions) || casted
        found = find_by_casted_values(simulator, recasted)
        return [found, false] if found
        raise
      end
    end
    raise "find_or_create! did not converge for #{parameters.inspect}"
  end

  # Finds the ParameterSet whose logical values equal `casted`, including
  # "legacy" PSs which have not yet been migrated after a parameter
  # definition was appended: a missing key matches only when the requested
  # value equals the key's default — which is exactly the value the
  # migration sweep will fill in.
  # MongoDB equality on Hash/Array values has surprising semantics
  # (array-element containment, subdocument key order), so the DB queries
  # act as pre-filters and a Ruby-side check is the authority.
  def self.find_by_casted_values(simulator, casted)
    defaults = casted_defaults_of(simulator)
    scope = simulator.parameter_sets

    # 1. exact per-key match; prefer fingerprinted docs (an exempted
    #    duplicate has none), then the oldest
    query = casted.map {|key,val| ["v.#{key}", val] }.to_h
    found = scope.where(query).desc(:fingerprint).asc(:created_at)
                 .detect {|ps| values_match?(ps, casted, defaults) }
    return found if found

    # 2. fingerprint (canonical form; key-order insensitive)
    found = scope.where(fingerprint: fingerprint_of(casted)).first
    return found if found

    # 3. legacy PSs with missing keys; only possible when some requested
    #    value equals its default
    legacy_keys = casted.keys.select {|key| defaults.key?(key) and defaults[key] == casted[key] }
    return nil if legacy_keys.empty?
    clauses = casted.map do |key,val|
      if legacy_keys.include?(key)
        { '$or' => [ { "v.#{key}" => val }, { "v.#{key}" => { '$exists' => false } } ] }
      else
        { "v.#{key}" => val }
      end
    end
    scope.where('$and' => clauses).asc(:created_at)
         .detect {|ps| values_match?(ps, casted, defaults) }
  end

  def self.casted_defaults_of(simulator)
    simulator.parameter_definitions.each_with_object({}) do |pd, h|
      next if pd.default.nil?
      val = ParametersUtil.cast_value(pd.default, pd.type)
      h[pd.key] = val unless val.nil?
    end
  end

  def self.values_match?(ps, casted, defaults)
    return false unless ps.v.is_a?(Hash)
    return false unless (ps.v.keys - casted.keys).empty?
    casted.all? do |key, val|
      ps.v.key?(key) ? ps.v[key] == val : defaults[key] == val
    end
  end

  MAX_LEGACY_MIGRATION_RETRY = 3

  # Fills the keys missing on a legacy PS with their default values, as
  # the migration sweep of append_parameter_definition would. A CAS on
  # (to_be_destroyed, fingerprint) guarantees that a concurrently
  # discarded PS is never resurrected and concurrent fillers do not
  # clobber each other. Returns the PS to use, or nil when the state
  # changed underneath and the caller should redo its lookup.
  def self.migrate_legacy!(ps, defaults)
    filled = ps.v.dup
    defaults.each {|key,val| filled[key] = val unless filled.key?(key) }
    return ps if filled == ps.v
    new_fingerprint = fingerprint_of(filled)
    begin
      updated = ParameterSet.where(id: ps.id, :to_be_destroyed.in => [nil,false], fingerprint: ps.fingerprint)
        .find_one_and_update({ '$set' => { v: filled, fingerprint: new_fingerprint } })
      updated ? ps.reload : nil
    rescue Mongo::Error::OperationFailure => ex
      raise unless duplicate_key_error?(ex)
      # a fully migrated duplicate already exists; return that winner.
      # The legacy PS is left to the sweep, which warns the operator.
      ParameterSet.where(fingerprint: new_fingerprint).first ||
        ParameterSet.where(simulator_id: ps.simulator_id, v: filled).ne(id: ps.id).first
    end
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
