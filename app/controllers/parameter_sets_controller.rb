class ParameterSetsController < ApplicationController

  def show
    @param_set = ParameterSet.find(params[:id])
    @simulator = @param_set.simulator
    @parameter_keys = @simulator.parameter_definitions.keys
    @runs = Run.where(parameter_set_id: @param_set).page(params[:page])
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
    @param_set = @simulator.parameter_sets.build(v: params[:parameters])

    respond_to do |format|
      if @param_set.save
        format.html { redirect_to @param_set, notice: 'New ParameterSet was successfully created.' }
        format.json { render json: @param_set, status: :created, location: @param_set }
      else
        format.html { render action: "new" }
        format.json { render json: @param_set.errors, status: :unprocessable_entity }
      end
    end
  end

  def _runs_count
    render json: ParameterSet.only("runs.status").find(params[:id]).runs_count.to_json
  end
end
