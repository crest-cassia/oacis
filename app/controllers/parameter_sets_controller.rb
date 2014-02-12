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
      v[defn.key] = defn.default unless defn.default.nil?
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
    result_keys = params[:y_axis_key].split('.')[1..-1]
    analyzer_name = params[:y_axis_key].split('.')[0]
    analyzer = ps.simulator.analyzers.where(name: analyzer_name).first
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
      collect_data_for_line_plot(base_ps, x_axis_key, analyzer, result_keys, irrelevant_keys)
    end

    respond_to do |format|
      format.json {
        render json: { xlabel: x_axis_key, ylabel: result_keys.last,
                       series: series, series_values: series_values, data: data}
      }
      format.plt {
        if series.blank?
          script = GnuplotUtil.script_for_single_line_plot(data[0], x_axis_key, result_keys.last, true)
        else
          script = GnuplotUtil.script_for_multi_line_plot(data, x_axis_key, result_keys.last, true,
                                                          series, series_values)
        end
        render text: script
      }
    end
  end

  private
  # return an array like follows
  #  [ [x, average, error, ps_id], .... ]
  def collect_data_for_line_plot(base_ps, x_axis_key, analyzer, result_keys, irrelevant_keys)
    ps_ids = []
    ps_id_to_x = {}
    base_ps.parameter_sets_with_different(x_axis_key, irrelevant_keys).each do |ps|
      ps_ids << ps.id
      ps_id_to_x[ps.id.to_s] = ps.v[x_axis_key]
    end

    plot_data = collect_result_values(ps_ids, analyzer, result_keys).map do |h|
      ps_id = h["_id"]
      [ ps_id_to_x[ps_id.to_s], h["average"], h["error"], ps_id ]
    end
    plot_data.sort_by {|d| d[0]}
  end

  # return an array like follows
  # [{"_id"=>"52bba7bab93f969a7900000f",
  #   "average"=>99.0, "error"=>0.2, "count"=>3},
  #  {...}, {...}, ... ]
  def collect_result_values(ps_ids, analyzer, result_keys)
    aggregated = []
    if analyzer.nil?
      aggregated = Run.collection.aggregate(
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
      aggregated = Analysis.collection.aggregate(
        { '$match' => Analysis.where(analyzer_id: analyzer.id, status: :finished)
                              .in(parameter_set_id: ps_ids)
                              .exists("result.#{result_keys.join('.')}" => true)
                              .selector },
        { '$sort' => {'updated_at' => -1} }, # get the latest analysis
        { '$project' => { parameter_set_id: '$parameter_set_id',
                          run_id: '$analyzable_id',
                          result_val: "$result.#{result_keys.join('.')}"
                        }},
        { '$group' => { _id: '$run_id',  # get one analysis for each run
                        parameter_set_id: {'$first' => '$parameter_set_id'},
                        result_val: {'$first' => '$result_val'}
                      }},
        { '$group' => { _id: '$parameter_set_id',  # calculate average for each parameter_set
                        average: {'$avg' => '$result_val'},
                        square_average: {'$avg' => {'$multiply' =>['$result_val', '$result_val']}},
                        count: {'$sum' => 1}
                      }}
        )
    elsif analyzer.type == :on_parameter_set
      aggregated = Analysis.collection.aggregate(
        { '$match' => Analysis.where(analyzer_id: analyzer.id, status: :finished)
                              .in(parameter_set_id: ps_ids)
                              .exists("result.#{result_keys.join('.')}" => true)
                              .selector },
        { '$sort' => {'updated_at' => -1} }, # get the latest analysis
        { '$project' => { parameter_set_id: '$parameter_set_id',
                          result_val: "$result.#{result_keys.join('.')}"
                        }},
        { '$group' => { _id: '$parameter_set_id',
                        average: {'$first' => '$result_val'},
                        square_average: {'$first' => {'$multiply' =>['$result_val', '$result_val']}},
                        count: {'$first' => 1}
                      }}
        )
    else
      raise "must not happen"
    end

    aggregated.map do |h|
      error = h["count"] > 1 ?
        Math.sqrt( (h["square_average"] - h["average"]**2) / (h["count"] - 1) ) : nil
      { "_id" => h["_id"], "average" => h["average"], "error" => error, "count" => h["count"] }
    end
  end

  def collect_latest_elapsed_times(ps_ids)
    Run.collection.aggregate(
      { '$match' => Run.in(parameter_set_id: ps_ids).where(status: :finished).selector },
      { '$sort' => { finished_at: -1 } },
      { '$group' => { _id: '$parameter_set_id',
                      real_time: {'$first' => '$real_time'},
                      cpu_time: {'$first' => '$cpu_time'}}}
      )
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
    ranges = params[:range] ? JSON.load(params[:range]) : {}

    found_ps = base_ps.parameter_sets_with_different(x_axis_key, [y_axis_key] + irrelevant_keys)
    ranges.each_pair do |key, range|
      found_ps = found_ps.where({ "v.#{key}" => {"$gte" => range.first, "$lte" => range.last} })
    end

    parameter_values = ParameterSet.collection.aggregate(
      { '$match' => found_ps.selector },
      { '$limit' => SCATTER_PLOT_LIMIT },
      { '$project' => {v: "$v"} }
      )
    # parameter_values should look like
    #   [{"_id"=>"52bb8662b93f96e193000007", "v"=> {...}}, {...}, {...}, ... ]

    result = nil
    if result_keys.present?
      ps_ids = parameter_values.map {|ps| ps["_id"]}
      result_values = collect_result_values(ps_ids, analyzer, result_keys)
      # result_values should look like
      # [{"_id"=>"52bba7bab93f969a7900000f",
      #   "average"=>99.0, "square_average"=>9801.0, "count"=>1},
      #  {...}, {...}, ... ]

      data = result_values.map do |h|
        found = parameter_values.find {|pv| pv["_id"] == h["_id"] }
        [found["v"], h["average"], h["error"], h["_id"]]
      end
      result = result_keys.last
    elsif params[:result] == "cpu_time" or params[:result] == "real_time"
      result = params[:result]
      ps_ids = parameter_values.map {|ps| ps["_id"]}
      elapsed_times = collect_latest_elapsed_times(ps_ids)
      # elapsed_times should look like
      # [{"_id" => "52bba7bab93f969a7900000f", "cpu_time"=>9.0, "real_time"=>3.0},
      #  {...}, {...}, ... ]
      data = elapsed_times.map do |h|
        found = parameter_values.find {|pv| pv["_id"] == h["_id"] }
        [found["v"], h[result], nil, h["_id"]]
      end
    else
      data = parameter_values.map do |pv|
        [pv["v"], nil, nil, pv["_id"]]
      end
    end

    respond_to do |format|
      format.json {
        render json: {xlabel: x_axis_key, ylabel: y_axis_key, result: result, data: data}
      }
    end
  end

  def _neighbor
    current = ParameterSet.find(params[:id])
    simulator = current.simulator

    param_keys = simulator.parameter_definitions.map(&:key)
    target_key = params[:key]
    raise "not found key #{target_key}" unless param_keys.include?(target_key)
    query = {simulator: simulator}
    param_keys.each do |key|
      next if key == target_key
      query["v.#{key}"] = current.v[key]
    end
    target_key_values = ParameterSet.where(query).distinct("v.#{target_key}").sort

    idx = target_key_values.index(current.v[target_key])
    if params[:direction] == "up"
      idx = (idx + 1) % target_key_values.size
    elsif params[:direction] == "down"
      idx = (idx - 1) % target_key_values.size
    else
      raise "must not happen"
    end
    query = query.merge({"v.#{target_key}" => target_key_values[idx] })
    @param_set = ParameterSet.where(query).first

    respond_to do |format|
      format.json { render json: @param_set }
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
