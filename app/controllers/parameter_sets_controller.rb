class ParameterSetsController < ApplicationController

  def show
    @param_set = ParameterSet.find(params[:id])
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @param_set }
    end
  end

  def new
    simulator = Simulator.find(params[:simulator_id])
    v = {}
    simulator.parameter_definitions.each do |defn|
      v[defn.key] = defn.default if defn.default
    end
    @param_set = simulator.parameter_sets.build(v: v)
  end

  def duplicate
    base_ps = ParameterSet.find(params[:id])
    simulator = base_ps.simulator
    @param_set = simulator.parameter_sets.build(v: base_ps.v)
    render :new
  end

  def create
    simulator = Simulator.find(params[:simulator_id])
    num_runs = params[:num_runs].to_i

    @param_set = simulator.parameter_sets.build(params)
    # this run is not saved, but used when rendering new
    @run = @param_set.runs.build(params[:run]) if num_runs > 0

    num_created = 0
    if num_runs == 0 or @run.valid?
      if params[:v].any? {|key,val| val.include?(',') }
        created = create_multiple(simulator, params[:v].dup)
        num_created = created.size
        created.each do |ps|
          num_runs.times {|i| ps.runs.create(params[:run]) }
        end
        if num_created >= 1
          @param_set = created.first
        else # num_created == 0
          @param_set.errors.add(:base, "No parameter_set was newly created")
        end
      else
        if @param_set.save
          num_runs.times {|i| @param_set.runs.create(params[:run]) }
          num_created = 1
        end
      end
    end

    respond_to do |format|
      if @param_set.persisted? and num_created == 1
        format.html { redirect_to @param_set, notice: 'New ParameterSet was successfully created.' }
        format.json { render json: @param_set, status: :created, location: @param_set }
      elsif @param_set.persisted? and num_created > 1
        format.html { redirect_to simulator, notice: "#{num_created} ParameterSets were created" }
        format.json { render json: simulator, status: :created, location: simulator }
      else
        @num_runs = num_runs
        format.html { render action: "new" }
        format.json { render json: @param_set.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @ps = ParameterSet.find(params[:id])
    @ps.destroy

    respond_to do |format|
      format.json { head :no_content }
      format.js
    end
  end

  def _runs_status_count
    render json: ParameterSet.only("runs.status").find(params[:id]).runs_status_count.to_json
  end

  def _runs_and_analyses
    param_set = ParameterSet.find(params[:id])
    render partial: "inner_table", locals: {parameter_set: param_set}
  end

  def _runs_list
    param_set = ParameterSet.find(params[:id])
    render json: RunsListDatatable.new(param_set.runs, view_context)
  end

  def _analyses_list
    parameter_set = ParameterSet.find(params[:id])
    render json: AnalysesListDatatable.new(view_context, parameter_set.analyses)
  end

  def _plot
    parameter_set = ParameterSet.find(params[:id])
    simulator = parameter_set.simulator

    x_axis_key = params[:x_axis_key]
    y_axis_keys = params[:y_axis_key].split('.')
    irrelevant_keys = params[:irrelevants].split(',')

    plot_data = []
    series_values = []
    series = params[:series]
    series = nil if series == x_axis_key
    if series.present?
      base_ps_array = parameter_set.parameter_sets_with_different(series, irrelevant_keys)
      base_ps_array.uniq {|ps| ps.v[series]}.each do |base_ps|
        plot_data << collect_data(base_ps, x_axis_key, y_axis_keys, irrelevant_keys)
        series_values << base_ps.v[series]
      end
    else
      plot_data << collect_data(parameter_set, x_axis_key, y_axis_keys, irrelevant_keys)
    end

    xlabel = x_axis_key
    ylabel = y_axis_keys.last
    data = plot_data.reverse
    series_values = series_values.reverse

    h = {xlabel: xlabel, ylabel: ylabel, series: series, series_values: series_values, data: data}
    render json: h
  end

  private
  def collect_data(base_ps, x_axis_key, y_axis_keys, irrelevant_keys)
    analyzer = nil
    y_axis_keys = y_axis_keys.dup
    analyzer_name = y_axis_keys.shift
    if analyzer_name.present?
      analyzer = base_ps.simulator.analyzers.where(name: analyzer_name).first
    end

    plot_data = []
    base_ps.parameter_sets_with_different(x_axis_key, irrelevant_keys).each do |ps|
      if analyzer.nil?
        runs = ps.runs.where(status: :finished)
        if runs.present?
          x = ps.v[x_axis_key]
          results = runs.map(&:result).map do |result|
            y_axis_keys.inject(result) {|y, y_key| y.try(:[], y_key) }
          end
          y, yerror = error_analysis(results.compact)
          plot_data << [x, y, yerror, ps.id]
        end
      elsif analyzer.type == :on_parameter_set
        analysis = analyzer.analyses.where(analyzable: ps, status: :finished).first
        if analysis
          x = ps.v[x_axis_key]
          result = analysis.result
          y = y_axis_keys.inject(result) {|y, y_key| y.try(:[], y_key) }
          plot_data << [x, y, nil, ps.id]
        end
      elsif analyzer.type == :on_run
        analyses = ps.runs.where(status: :finished).map do |run|
          run.analyses.where(analyzer: analyzer, status: :finished).first
        end.compact
        if analyses.present?
          x = ps.v[x_axis_key]
          results = analyses.map(&:result).map do |result|
            y_axis_keys.inject(result) {|y, y_key| y.try(:[], y_key) }
          end
          y, yerror = error_analysis(results.compact)
          plot_data << [x, y, yerror, ps.id]
        end
      end
    end
    plot_data
  end

  def error_analysis(data)
    n = data.size
    ave = data.inject(:+).to_f / n
    err = nil
    err = Math.sqrt( data.map {|x| (x-ave)*(x-ave) }.inject(:+) / (n*(n-1)) ) if n > 1
    return ave, err
  end

  private
  MAX_CREATION_SIZE = 100
  # return created parameter sets
  def create_multiple(simulator, parameters)
    mapped = simulator.parameter_definitions.map do |defn|
      key = defn.key
      if parameters[key] and JSON.is_not_json?(parameters[key]) and parameters[key].include?(',')
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
      simulator.parameter_definitions.each_with_index do |defn, idx|
        param[defn.key] = param_ary[idx]
      end
      ps = simulator.parameter_sets.build(v: param)
      if ps.save
        created << ps
      end
    end
    created
  end
end
