class ParameterSetsController < ApplicationController

  def show
    @param_set = ParameterSet.find(params[:id])
    @simulator = @param_set.simulator
    @parameter_keys = @simulator.parameter_definitions.keys
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @param_set }
    end
  end

  def new
    @simulator = Simulator.find(params[:simulator_id])
    v = {}
    @simulator.parameter_definitions.each do |key,defn|
      v[key] = defn["default"] if defn["default"]
    end
    @param_set = @simulator.parameter_sets.build(v: v)
  end

  def duplicate
    base_ps = ParameterSet.find(params[:id])
    @simulator = base_ps.simulator
    @param_set = @simulator.parameter_sets.build(v: base_ps.v)
    render :new
  end

  def create
    @simulator = Simulator.find(params[:simulator_id])
    num_runs = params[:num_runs].to_i
    num_created = 0
    if params[:parameters].any? {|key,val| val.include?(',') }
      created = create_multiple(@simulator, params[:parameters].dup)
      num_created = created.size
      created.each do |ps|
        num_runs.times {|i| ps.runs.create }
      end
      if created.size == 1
        @param_set = created.first
      else created.size == 0
        @param_set = @simulator.parameter_sets.build(v: params[:parameters])
      end
    else
      @param_set = @simulator.parameter_sets.build(v: params[:parameters])
    end

    respond_to do |format|
      if @param_set and @param_set.save
        num_runs.times {|i| @param_set.runs.create }
        format.html { redirect_to @param_set, notice: 'New ParameterSet was successfully created.' }
        format.json { render json: @param_set, status: :created, location: @param_set }
      elsif num_created > 1
        format.html { redirect_to @simulator, notice: "#{num_created} ParameterSets were created" }
        format.json { render json: @simulator, status: :created, location: @simulator }
      else
        format.html { render action: "new" }
        format.json { render json: @param_set.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @ps = ParameterSet.find(params[:id])
    sim = @ps.simulator
    @ps.destroy

    respond_to do |format|
      format.html { redirect_to simulator_url(sim) }
      format.json { head :no_content }
    end
  end

  def _runs_status_count
    render json: ParameterSet.only("runs.status").find(params[:id]).runs_status_count.to_json
  end

  def _runs_table
    @param_set = ParameterSet.find(params[:id])
    render :partial => "inner_table"
  end

  def _runs_list
    param_set = ParameterSet.find(params[:id])
    render json: RunsListDatatable.new(param_set.runs, view_context)
  end

  private
  MAX_CREATION_SIZE = 100
  # return created parameter sets
  def create_multiple(simulator, parameters)
    mapped = simulator.parameter_definitions.map do |key, defn|
      if parameters[key] and parameters[key].include?(',')
        casted = parameters[key].split(',').map {|x|
          ParametersUtil.cast_value( x.strip, defn["type"] )
        }
        casted.compact.uniq.sort
      else
        (parameters[key] || defn["default"]).to_a
      end
    end

    creation_size = mapped.inject(1) {|prod, x| prod * x.size }
    if creation_size > MAX_CREATION_SIZE
      flash[:alert] = "number of created parameter sets must be less than #{MAX_CREATION_SIZE}"
      return []
    end

    created = []
    patterns = mapped[0].product( *mapped[1..-1] ).each do |param_ary|
      param = {}
      simulator.parameter_definitions.keys.each_with_index do |key, idx|
        param[key] = param_ary[idx]
      end
      ps = @simulator.parameter_sets.build(v: param)
      if ps.save
        created << ps
      end
    end
    created
  end
end
