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

  def _line_plot
    ps = ParameterSet.find(params[:id])

    x_axis_key = params[:x_axis_key]
    y_axis_keys = params[:y_axis_key].split('.')
    irrelevant_keys = params[:irrelevants].split(',')

    series = (params[:series] != x_axis_key) ? params[:series] : nil
    if series.present?
      ps_array = ps.parameter_sets_with_different(series, irrelevant_keys)
        .uniq {|ps| ps.v[series] }
        .reverse # reverse the order so that the series are displayed in descending order
      series_values = ps_array.map {|base_ps| base_ps.v[series] }
    else
      ps_array = [ps]
      series_values = []
    end
    data = ps_array.map do |base_ps|
      collect_data(base_ps, x_axis_key, y_axis_keys, irrelevant_keys)
    end

    h = {
      xlabel: x_axis_key,
      ylabel: y_axis_keys.last,
      series: series,
      series_values: series_values,
      data: data
    }
    respond_to do |format|
      format.json { render json: h }
      format.plt {
        if series.blank?
          script = GnuplotUtil.script_for_single_line_plot(data[0], x_axis_key, y_axis_keys.last, true)
        else
          script = GnuplotUtil.script_for_multi_line_plot(data, x_axis_key, y_axis_keys.last, true,
                                                            series, series_values)
        end
        render text: script
      }
    end
  end

  private
  def collect_data(base_ps, x_axis_key, y_axis_keys, irrelevant_keys)
    y_axis_keys = y_axis_keys.dup
    analyzer_name = y_axis_keys.shift
    analyzer = base_ps.simulator.analyzers.where(name: analyzer_name).first

    ps_ids = []
    ps_id_to_x = {}
    base_ps.parameter_sets_with_different(x_axis_key, irrelevant_keys).each do |ps|
      ps_ids << ps.id
      ps_id_to_x[ps.id.to_s] = ps.v[x_axis_key]
    end

    plot_data = collect_result_values(ps_ids, analyzer, y_axis_keys).map do |result_val|
      ps_id = result_val["_id"]
      x = ps_id_to_x[ps_id.to_s]
      y = result_val["average"]
      error = nil
      if result_val["count"] > 1
        err_sq = (result_val["square_average"] - result_val["average"]**2) / (result_val["count"] - 1)
        error = Math.sqrt(err_sq)
      end
      [x, y, error, ps_id]
    end
    plot_data.sort_by {|d| d[0]}
  end

  # return an array like follows
  # [{"_id"=>"52bba7bab93f969a7900000f",
  #   "average"=>99.0, "square_average"=>9801.0, "count"=>1},
  #  {...}, {...}, ... ]
  def collect_result_values(ps_ids, analyzer, result_keys)
    if analyzer.nil?
      Run.collection.aggregate(
        { '$match' => Run.in(parameter_set_id: ps_ids)
                         .where(status: :finished)
                         .exists("result.#{result_keys.join('.')}" => true)
                         .selector },
        { '$project' => { parameter_set_id: 1,
                          result_val: "$result.#{result_keys.join('.')}"
                        }},
        { '$group' => { _id: '$parameter_set_id',
                        average: {'$avg' => '$result_val'},
                        square_average: {'$avg' => {'$multiply' =>['$result_val', '$result_val']} },
                        count: {'$sum' => 1}
                      }}
        )
    elsif analyzer.type == :on_run
      run_id_to_ps_id = {}
      run_ids = []
      Run.in(parameter_set_id: ps_ids).where(status: :finished).only(:_id, :parameter_set_id).each {|run|
        run_id_to_ps_id[run.id] = run.parameter_set_id
        run_ids << run.id
      }

      result_values = Analysis.collection.aggregate(
        {'$match' => Analysis.where(analyzer_id: analyzer.id, status: :finished)
                             .in(analyzable_id: run_ids)
                             .exists("result.#{result_keys.join('.')}" => true)
                             .selector },
        { '$sort' => {'updated_at' => -1} }, # get the latest analysis
        { '$project' => { run_id: '$analyzable_id',
                          result_val: "$result.#{result_keys.join('.')}"
                        }},
        { '$group' => { _id: '$run_id',
                        result_val: {'$first' => '$result_val'}  # get one analysis for each run
                      }}
        )
      # result_values should look like
      # [{"_id"=>"522d7631899e53481800012d", "result_val"=>-0.776064}, {...}, {...}, ...]

      run_id_to_result = Hash[ result_values.map {|r| [r["_id"], r["result_val"]] } ]
      # run_id_to_result should look like
      # { "522d7631899e53481800012d" => -0.776064, ....}

      ps_id_to_results = {}
      run_id_to_result.each_pair do |run_id, result_val|
        ps_id = run_id_to_ps_id[run_id]
        (ps_id_to_results[ps_id] ||= []) << result_val
      end

      ps_id_to_results.map do |ps_id, values|
        count = values.size
        average = values.inject(0, :+).to_f / count
        square_average = ( values.map {|v| v*v}.inject(0, :+) ).to_f / count
        { "_id" => ps_id,
          "average" => average, "square_average" => square_average, "count" => count }
      end
    elsif analyzer.type == :on_parameter_set
      Analysis.collection.aggregate(
        { '$match' => Analysis.where(analyzer_id: analyzer.id, status: :finished)
                              .in(analyzable_id: ps_ids)
                              .exists("result.#{result_keys.join('.')}" => true)
                              .selector },
        { '$sort' => {'updated_at' => -1} }, # get the latest analysis
        { '$project' => { parameter_set_id: '$analyzable_id',
                          result_val: "$result.#{result_keys.join('.')}"
                        }},
        { '$group' => { _id: '$parameter_set_id',
                        average: {'$first' => '$result_val'},
                        square_average: {'$first' => {'$multiply' =>['$result_val', '$result_val']}},
                        count: {'$first' => 1}
                      }}
        )
    end
  end

  SCATTER_PLOT_LIMIT = 1000

  public
  def _scatter_plot
    base_ps = ParameterSet.find(params[:id])

    x_axis_key = params[:x_axis_key]
    y_axis_key = params[:y_axis_key]
    result_keys = params[:result].split('.')[1..-1]
    analyzer_name = params[:result].split('.')[0]
    analyzer = base_ps.simulator.analyzers.where(name: analyzer_name).first
    irrelevant_keys = params[:irrelevants].split(',')

    found_ps = base_ps.parameter_sets_with_different(x_axis_key, [y_axis_key] + irrelevant_keys)
    parameter_values = ParameterSet.collection.aggregate(
      { '$match' => found_ps.selector },
      { '$limit' => SCATTER_PLOT_LIMIT },
      { '$project' => {x: "$v.#{x_axis_key}", y: "$v.#{y_axis_key}"} }
      )
    # parameter_values should look like
    #   [{"_id"=>"52bb8662b93f96e193000007", "x"=>1, "y"=>1.0}, {...}, {...}, ... ]

    ps_ids = parameter_values.map {|ps| ps["_id"]}

    result_values = collect_result_values(ps_ids, analyzer, result_keys)
    # result_values should look like
    # [{"_id"=>"52bba7bab93f969a7900000f",
    #   "average"=>99.0, "square_average"=>9801.0, "count"=>1},
    #  {...}, {...}, ... ]

    data = result_values.map do |avg|
      ps_id = avg["_id"]
      found_pv = parameter_values.find {|pv| pv["_id"] == ps_id }
      x = found_pv["x"]
      y = found_pv["y"]
      average = avg["average"]
      error = nil
      if avg["count"] > 1
        err_sq = (avg["square_average"] - avg["average"]**2) / (avg["count"] - 1)
        error = Math.sqrt(err_sq)
      end
      [x, y, average, error, ps_id]
    end

    h = {
      xlabel: x_axis_key,
      ylabel: y_axis_key,
      result: result_keys.last,
      data: data
    }

    respond_to do |format|
      format.json { render json: h }
    end
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
