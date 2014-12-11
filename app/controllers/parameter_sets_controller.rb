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
    @num_runs = params[:num_runs].to_i

    previous_num_ps = simulator.parameter_sets.count
    previous_num_runs = simulator.runs.count

    @param_set = simulator.parameter_sets.build(params)
    # this run is not saved, but used when rendering new
    if @num_runs > 0
      @run = @param_set.runs.build(params[:run])
      unless @run.valid?
        render action: "new"
        return
      end
    end

    created = find_or_create_multiple(simulator, params[:v].dup)

    if created.empty?
      @param_set.errors.add(:base, "No parameter_set was created")
      render action: "new"
      return
    end

    @num_runs.times do |i|
      created.each do |ps|
        next if ps.runs.count > i
        ps.runs.create(params[:run])
      end
    end

    num_created_ps = simulator.reload.parameter_sets.count - previous_num_ps
    num_created_runs = simulator.runs.count - previous_num_runs
    if num_created_ps == 0 and num_created_runs == 0
      @param_set.errors.add(:base, "No parameter_sets or runs are created")
      render action: "new"
      return
    end

    flash[:notice] = "#{num_created_ps} ParameterSets and #{num_created_runs} runs were created"
    if created.size == 1
      @param_set = created.first
      redirect_to @param_set
    else
      redirect_to simulator
    end
  end

  def _create_cli
    simulator = Simulator.find(params[:simulator_id])
    parameters = params[:v].dup

    casted_parameters = {}
    simulator.parameter_definitions.each do |defn|
      key = defn.key
      casted = nil
      if parameters[key] and JSON.is_not_json?(parameters[key]) and parameters[key].include?(',')
        casted = parameters[key].split(',').map {|x|
          ParametersUtil.cast_value( x.strip, defn["type"] )
        }.compact.uniq
      else
        casted = parameters.has_key?(key) ? ParametersUtil.cast_value(parameters[key],defn["type"]) : defn["default"]
      end
      casted_parameters[key] = casted
    end
    ps_json_escaped = casted_parameters.to_json.gsub("'","'\\\\''")

    cmd = "./bin/oacis_cli create_parameter_sets -s #{simulator.id} -i '#{ps_json_escaped}'"

    num_runs = params[:num_runs].to_i
    if num_runs > 0
      run_option = {}
      run_option[:num_runs] = num_runs
      run_option[:mpi_procs] = params[:run][:mpi_procs].to_i
      run_option[:omp_threads] = params[:run][:omp_threads].to_i
      run_option[:priority] = params[:run][:priority].to_i
      run_option[:submitted_to] = params[:run][:submitted_to].length > 0 ? params[:run][:submitted_to] : nil # when manual submission is selected, the parameter value is empty string "".
      run_option[:host_parameters] = params[:run][:host_parameters]
      run_option_escaped = run_option.to_json.gsub("'", "'\\\\''")
      cmd += " -r '#{run_option_escaped}'"
    end

    cmd += " -o ps.json"

    render text: cmd
  end

  def destroy
    @ps = ParameterSet.find(params[:id])
    simulator = Simulator.find(@ps.simulator_id)
    @ps.destroy

    respond_to do |format|
      format.json { head :no_content }
      format.js
      format.html { redirect_to simulator_path(simulator) }
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

  def _similar_parameter_sets_list
    base_ps = ParameterSet.find(params[:id])
    keys = base_ps.simulator.parameter_definitions.map(&:key)
    selectors = keys.map {|key| base_ps.parameter_sets_with_different(key).selector }
    parameter_sets = ParameterSet.or(*selectors)
    render json: ParameterSetsListDatatable.new(parameter_sets, keys, view_context, base_ps)
  end

  def _line_plot
    ps = ParameterSet.find(params[:id])

    x_axis_key = params[:x_axis_key]
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

    ylabel = nil
    data = nil
    # get data
    if ["cpu_time", "real_time"].include?(params[:y_axis_key])
      ylabel = params[:y_axis_key]
      data = ps_array.map do |base_ps|
        collect_elapsed_times_for_line_plot(base_ps, x_axis_key, ylabel, irrelevant_keys)
      end
    else
      result_keys = params[:y_axis_key].split('.')[1..-1]
      analyzer_name = params[:y_axis_key].split('.')[0]
      analyzer = ps.simulator.analyzers.where(name: analyzer_name).first
      data = ps_array.map do |base_ps|
        collect_data_for_line_plot(base_ps, x_axis_key, analyzer, result_keys, irrelevant_keys)
      end
      ylabel = result_keys.last
    end

    respond_to do |format|
      format.json {
        render json: { xlabel: x_axis_key, ylabel: ylabel,
                       series: series, series_values: series_values,
                       irrelevants: irrelevant_keys,
                       data: data
                     }
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
  #  [ [x, elapsed_time, nil, ps_id], .... ]
  def collect_elapsed_times_for_line_plot(base_ps, x_axis_key, y_axis_key, irrelevant_keys)
    ps_ids = []
    ps_id_to_x = {}
    base_ps.parameter_sets_with_different(x_axis_key, irrelevant_keys).each do |ps|
      ps_ids << ps.id
      ps_id_to_x[ps.id.to_s] = ps.v[x_axis_key]
    end

    plot_data = collect_latest_elapsed_times(ps_ids).map do |h|
      ps_id = h["_id"]
      [ ps_id_to_x[ps_id.to_s], h[y_axis_key], nil, ps_id ]
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
      d = h["square_average"]-h["average"]**2
      error = (h["count"] > 1 and d > 0.0) ?
        Math.sqrt( d / (h["count"] - 1) ) : nil
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

  SCATTER_PLOT_LIMIT = 10000

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
    elsif ["cpu_time", "real_time"].include?(params[:result])
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
      result = nil
      data = parameter_values.map do |pv|
        [pv["v"], nil, nil, pv["_id"]]
      end
    end

    respond_to do |format|
      format.json {
        render json: {
          xlabel: x_axis_key, ylabel: y_axis_key, result: result,
          irrelevants: irrelevant_keys, data: data
        }
      }
    end
  end

  private
  def collect_latest_analyses(ps_ids, analyzer)
    Analysis.collection.aggregate(
      { '$match' => Analysis.where(analyzer: analyzer).in(parameter_set_id: ps_ids).where(status: :finished).selector },
      { '$sort' => { finished_at: -1 } },
      { '$group' => { _id: '$parameter_set_id',
                      analysis_id: {'$first' => '$_id'},
                      analyzable_id: {'$first' => '$analyzable_id'}}}
      )
  end

  def collect_latest_runs(ps_ids)
    Run.collection.aggregate(
      { '$match' => Run.in(parameter_set_id: ps_ids).where(status: :finished).selector },
      { '$sort' => { finished_at: -1 } },
      { '$group' => { _id: '$parameter_set_id',
                      run_id: {'$first' => '$_id'}}}
      )
  end

  public
  def _figure_viewer
    base_ps = ParameterSet.find(params[:id])

    x_axis_key = params[:x_axis_key]
    y_axis_key = params[:y_axis_key]
    analyzer_name, figure_filename = params[:result].split('/')
    analyzer = base_ps.simulator.analyzers.where(name: analyzer_name).first
    irrelevant_keys = params[:irrelevants].split(',')

    found_ps = base_ps.parameter_sets_with_different(x_axis_key, [y_axis_key] + irrelevant_keys)

    if analyzer
      related_anls = collect_latest_analyses(found_ps.map(&:id), analyzer).map do |ps_anl|
        [ps_anl["_id"], {analysis_id: ps_anl["analysis_id"], analyzable_id: ps_anl["analyzable_id"]}]
      end
      related_anls = Hash[*related_anls.flatten]

      if analyzer.type == :on_parameter_set
        data = found_ps.map do |ps|
          fig_path = nil
          if related_anls.has_key?(ps.id)
            path = ps.dir.join(related_anls[ps.id][:analysis_id]).join(figure_filename)
            fig_path = ApplicationController.helpers.file_path_to_link_path(path) if File.exist?(path)
          end
          [ ps.v[x_axis_key], ps.v[y_axis_key], fig_path.to_s, ps.id.to_s ]
        end
      elsif analyzer.type == :on_run
        data = found_ps.map do |ps|
          fig_path = nil
          if related_anls.has_key?(ps.id)
            path = ps.dir.join(related_anls[ps.id][:analyzable_id])
              .join(related_anls[ps.id][:analysis_id]).join(figure_filename)
            fig_path = ApplicationController.helpers.file_path_to_link_path(path) if File.exist?(path)
          end
          [ ps.v[x_axis_key], ps.v[y_axis_key], fig_path.to_s, ps.id.to_s ]
        end
      end
    else
      related_runs = collect_latest_runs(found_ps.map(&:id)).map do |ps_run|
        [ps_run["_id"], {run_id: ps_run["run_id"]}]
      end
      related_runs = Hash[*related_runs.flatten]
      data = found_ps.map do |ps|
        fig_path = nil
        if related_runs.has_key?(ps.id)
          path = ps.dir.join(related_runs[ps.id][:run_id]).join(figure_filename)
          fig_path = ApplicationController.helpers.file_path_to_link_path(path) if File.exist?(path)
        end
        [ ps.v[x_axis_key], ps.v[y_axis_key], fig_path.to_s, ps.id.to_s ]
      end
    end

    respond_to do |format|
      format.json {
        render json: { xlabel: x_axis_key, ylabel: y_axis_key,
                       result: params[:result], irrelevants: irrelevant_keys, data: data}
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
  def find_or_create_multiple(simulator, parameters)
    mapped = simulator.parameter_definitions.map do |defn|
      key = defn.key
      if parameters[key] and JSON.is_not_json?(parameters[key]) and parameters[key].include?(',')
        casted = parameters[key].split(',').map {|x|
          ParametersUtil.cast_value( x.strip, defn["type"] )
        }
        casted.compact.uniq.sort
      else
        [ parameters.has_key?(key) ? parameters[key] : defn["default"] ]
      end
    end

    creation_size = mapped.inject(1) {|prod, x| prod * x.size }
    if creation_size > MAX_CREATION_SIZE
      flash[:alert] = "number of created parameter sets must be less than #{MAX_CREATION_SIZE}"
      return []
    end

    created = []
    mapped[0].product( *mapped[1..-1] ).each do |param_ary|
      param = {}
      simulator.parameter_definitions.each_with_index do |defn, idx|
        param[defn.key] = param_ary[idx]
      end
      casted = ParametersUtil.cast_parameter_values(param, simulator.parameter_definitions)
      ps = simulator.parameter_sets.find_or_initialize_by(v: casted)
      if ps.persisted? or ps.save
        created << ps
      end
    end
    created
  end
end
