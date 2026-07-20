class SaveTask
  include Mongoid::Document
  field :param_values, type: Hash  # {p1: [1,2,3], p2: [4], ...}
  field :run_params, type: Hash
  field :num_runs, type: Integer
  field :cancel_flag, type: Mongoid::Boolean, default: false
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
          begin
            ps, _new_ps = ParameterSet.find_or_create!(simulator, v)
            created << ps
          rescue Mongoid::Errors::Validations
            # skip an invalid parameter combination (previously a silent save failure)
          end
        else
          break
        end
      else
        v = Hash[definitions.zip(param_values).map {|defn, v| [defn.key, v]}]
        begin
          ps, _new_ps = ParameterSet.find_or_create!(simulator, v)
          created << ps
        rescue Mongoid::Errors::Validations
          # skip an invalid parameter combination (previously a silent save failure)
        end
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
      # sequential seeds are assigned in Run#set_unique_seed at save time;
      # the unique index on (parameter_set_id, seed) makes this race-safe
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
end
