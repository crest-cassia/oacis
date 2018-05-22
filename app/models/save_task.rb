class SaveTask
  include Mongoid::Document
  field :param_values, type: Hash  # {p1: [1,2,3], p2: [4], ...}
  field :run_params, type: Hash
  field :num_runs, type: Integer
  field :cancel_flag, type: Boolean, default: false
  field :creation_size, type: Integer

  belongs_to :simulator

  validates :param_values, presence: true
  validates :num_runs, presence: true
  validates :simulator_id, presence: true
  validates :creation_size, presence: true

  after_build :_calculate_creation_size

  private
  def _calculate_creation_size
    self.creation_size = param_values.inject(1) {|memo, (k,v)| memo * v.size }
  end

  public
  NOW_CREATION_SIZE=10
  def make_ps_in_batches(now = false)
    if num_runs > 0
      run_params_p = ActionController::Parameters.new(run_params)
      run_params_p.permit!
    end

    definitions = simulator.parameter_definitions
    mapped = definitions.map {|defn| param_values[defn.key] }
    created = []
    mapped[0].product( *mapped[1..-1] ).each_with_index do |param_values, i|
      return created if (i%10 == 0) and (now == false) and (self.reload.cancel_flag == true)
      if now
        if i < NOW_CREATION_SIZE
          v = Hash[definitions.zip(param_values).map {|defn, v| [defn.key, v]}]
          ps = simulator.parameter_sets.find_or_initialize_by(v: v)
          created << ps if ps.persisted? or ps.save
        else
          break
        end
      else
        v = Hash[definitions.zip(param_values).map {|defn, v| [defn.key, v]}]
        ps = simulator.parameter_sets.find_or_initialize_by(v: v)
        created << ps if ps.persisted? or ps.save
        StatusChannel.broadcast_to('message', OacisChannelUtil.progressSaveTaskMessage(simulator, -i-1)) if i%100==0
      end
    end

    if (now && creation_size <= NOW_CREATION_SIZE) or (now == false)
      new_runs = []
      num_runs.times do |i|
        return created if (now == false) and (self.reload.cancel_flag == true)
        created.each do |ps|
          next if ps.runs.count > i
          new_runs << ps.runs.build(run_params_p)
        end
      end
      set_sequential_seeds(new_runs) if simulator.sequential_seed
      new_runs.each_with_index do |r,idx|
        r.save
        if now == false && idx % 20 == 0
          StatusChannel.broadcast_to('message', OacisChannelUtil.progressSaveTaskMessage(simulator, -created.size, -idx-1))
        end
      end
    end
    created
  end

  def remaining?
    creation_size > NOW_CREATION_SIZE
  end

  private
  def set_sequential_seeds(runs)
    ps_runs = runs.group_by {|run| run.parameter_set }
    ps_runs.each_pair do |ps, runs_in_ps|
      seeds = ps.reload.runs.asc(:seed).only(:seed).map {|r| r.seed }
      runs_in_ps.each do |run_in_ps|
        found = seeds.each_with_index.find {|seed,idx| seed != idx + 1 }
        next_seed_idx = found ? found[1] : seeds.size
        run_in_ps.seed = next_seed_idx + 1
        seeds.insert(next_seed_idx, next_seed_idx + 1 )
      end
    end
  end

end
