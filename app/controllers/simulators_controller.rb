class SimulatorsController < ApplicationController
  # GET /simulators
  # GET /simulators.json
  def index
    @simulators = Simulator.asc(:position).all
    FileUtils.mkdir_p( ResultDirectory.root ) # to assure the existence of the result dir
    rate = DiskSpaceChecker.rate
    flash[:alert] = "No enough space is left on device (Usage: #{rate*100}%)" if rate >= 0.9
    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @simulators }
    end
  end

  # GET /simulators/1
  # GET /simulators/1.json
  def show
    @simulator = Simulator.find(params[:id])
    @analyzers = @simulator.analyzers
    @query_id = params[:query_id]

    @filter_set_id = params[:filter_set_id]
    @filter_set_name = ""
    @filter_set_query_string = "No filter selected."
    logger.debug "filter_set_id: " + @filter_set_id.to_s
    if @filter_set_id.present? && @filter_set_id != "undefined"
      filter_set = FilterSet.find(@filter_set_id)
      @filter_set_name = filter_set.name
      a = []
      filter_set.parameter_set_filters.each do |filter|
        logger.debug "Loop filter " + filter.enable.to_s
        logger.debug "Loop filter " + filter.query.to_s
        next unless filter.enable
        a << ParametersUtil.parse_query_hash_to_str(filter.query, @simulator)
      end
      @filter_set_query_string = a.join(" and ")
    end
    logger.debug "filter_set_query_string: " + @filter_set_query_string

    if @simulator.parameter_set_queries.present?
      @query_list = {}
      @simulator.parameter_set_queries.each do |psq|
        @query_list[psq.query.to_s] = psq.id
      end
    end

    respond_to do |format|
      format.html
      format.json
    end
  end

  # GET /simulators/new
  # GET /simulators/new.json
  def new
    @simulator = Simulator.new

    respond_to do |format|
      format.html
      format.json { render json: @simulator }
    end
  end

  # GET /simulators/1/duplicate
  def duplicate
    @duplicating_simulator = Simulator.find(params[:id])
    @copied_analyzers = @duplicating_simulator.analyzers
    @simulator = @duplicating_simulator.clone
    render :new
  end

  # GET /simulators/1/edit
  def edit
    @simulator = Simulator.find(params[:id])
  end

  # POST /simulators
  # POST /simulators.json
  def create
    @simulator = Simulator.new(permitted_simulator_params)
    if params[:duplicating_simulator]
      @duplicating_simulator = Simulator.find(params[:duplicating_simulator])
      if params[:copied_analyzers].present?
        @copied_analyzers = params[:copied_analyzers].map {|azr_id| Analyzer.find(azr_id) }
      else
        @copied_analyzers = []
      end
      @copied_analyzers.each do |azr|
        @simulator.analyzers.push azr.clone
      end
    end

    respond_to do |format|
      if @simulator.save
        format.html { redirect_to @simulator, notice: 'Simulator was successfully created.' }
        format.json { render json: @simulator, status: :created, location: @simulator }
      else
        format.html { render action: "new" }
        format.json { render json: @simulator.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /simulators/1
  # PUT /simulators/1.json
  def update
    @simulator = Simulator.find(params[:id])

    respond_to do |format|
      if @simulator.update_attributes(permitted_simulator_params.to_h)
        format.html { redirect_to @simulator, notice: 'Simulator was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @simulator.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /simulators/1
  # DELETE /simulators/1.json
  def destroy
    @simulator = Simulator.find(params[:id])
    @simulator.discard

    respond_to do |format|
      format.html { redirect_to simulators_url }
      format.json { head :no_content }
    end
  end

  # /simulator/:id/_filter_set_list
  def _filter_set_list
    logger.debug "_filter_set_list"
    simulator = Simulator.find(params[:id])
    if simulator.filter_sets.present?
      filter_sets = simulator.filter_sets
    else
      logger.debug "filter_set not exist. "
    end
    logger.debug "_filter_set_list render"
    render json: FilterSetListDatatable.new(filter_sets, simulator, view_context)
  end

  # /simulator/:id/_parameter_set_filter_list/:filter_set_id
  def _parameter_set_filter_list
    logger.debug "_parameter_set_filter_list"
    logger.debug "params= " + params.to_s
    
    simulator = Simulator.find(params[:id])
    bExist = true
    if params[:filter_set_id].present? && params[:filter_set_id] != "undefined"
      filter_set = simulator.filter_sets.find(params[:filter_set_id])
      filter_list = ParameterSetFilter.where({"filter_set_id": params[:filter_set_id]})
      logger.debug "class: " + filter_list.class.to_s
      
      filter_list.each do |fl|
        logger.debug "filter_list: " + fl.query.to_s
      end
    else
      bExist = false
      logger.debug "filter_list not exist."
    end
    render json: FilterListDatatable.new(filter_list, simulator, view_context, bExist)
  end

  # POST /simulators/:_id/_save_filter_set
  def _save_filter_set
    logger.debug "save Filter"
    
    filter_set_id = params[:filter_set_id]
    filters_str = params[:filter_query_array]
    logger.debug "filters_str: " + filters_str
    filters = JSON.parse(filters_str)
    logger.debug "filters: " + filters.to_s
    @simulator = Simulator.find(params[:id])
    @new_filter_set = nil
    if filter_set_id != "undefined" && @simulator.filter_sets.find(filter_set_id).name == params[:name]
      @new_filter_set = @simulator.filter_sets.find(filter_set_id)
      @new_filter_set.parameter_set_filters.destroy()
    else 
      @new_filter_set = @simulator.filter_sets.build
      @new_filter_set.name = params[:name]
      unless @new_filter_set.save 
        flash.now[:alert] = "Failed to create a filter set" + @new_filter_set.errors.full_messages.to_s
      end
    end
    logger.debug "params: " + params.to_s
    logger.debug "Filter name: " + params[:name].to_s

    new_filters = []
    filters.each_with_index do |param, i|
      filter_hash = ParametersUtil.parse_query_str_to_hash(param["query"])
      filter_hash["enable"] = param["enable"]
      logger.debug "filter_hash: " + filter_hash.to_s
      new_filters << @new_filter_set.parameter_set_filters.build
      new_filters[i].simulator = @simulator
      new_filters[i].filter_set = @new_filter_set
      new_filters[i].set_one_query(filter_hash)
    end

    if new_filters.map(&:save)
      flash.now[:notice] = "A new filter set is created or over writed."
    else
      flash.now[:notice] = "Failed to create a filter set."
    end

 #   if @new_filter_set.set_filters(filters) and @new_parameter_set_filters.save
 #     @filter_set_id = @new_filter_set.id.to_s
 #     flash[:notice] = "A new filter set is created"
 #   else
 #     flash[:alert] = "Failed to create a filter set"
 #   end
    
  end

  # POST /simulators/:_id/_set_filter_set redirect_to simulators#show
  def _set_filter_set
    logger.debug "set Filter set"

    filter_set_name = params[:filter_set_name_for_set]
    if filter_set_name.present?
      logger.debug "Filter set name: " + filter_set_name
      binding.pry
      @simulator = Simulator.find(params[:id])
      filter_set = @simulator.filter_sets.where({name: filter_set_name})
      filter_set.each do |fs|
        @filter_set_id = fs.id
      end
    end
    redirect_to  :action => "show", :filter_set_id => @filter_set_id
  end

  # POST /simulators/:_id/_make_query redirect_to simulators#show
  def _make_query
    @query_id = params[:query_id]

    if params[:delete_query]
      @q = ParameterSetQuery.find(@query_id)
      @q.destroy
      @query_id = nil
    else
      @simulator = Simulator.find(params[:id])
      @new_query = @simulator.parameter_set_queries.build
      if @new_query.set_query(params["query"]) and @new_query.save
        @query_id = @new_query.id.to_s
        flash[:notice] = "A new query is created"
      else
        flash[:alert] = "Failed to create a query"
      end
    end

    redirect_to  :action => "show", :query_id => @query_id
  end

  def _parameters_list
    simulator = Simulator.find(params[:id])
    parameter_sets = simulator.parameter_sets
    if params[:filter_set_id].present?
      f = FilterSet.find(params[:filter_set_id])
      parameter_sets = f.parameter_sets
    end
    keys = simulator.parameter_definitions.map {|pd| pd.key }
    num_ps_total = simulator.parameter_sets.count
    render json: ParameterSetsListDatatable.new(parameter_sets, keys, view_context, num_ps_total)
  end

  def _analyzer_list
    render json: AnalyzersListDatatable.new(view_context)
  end

  def _progress
    sim = Simulator.find(params[:id])
    first_parameter = params[:column_parameter]
    second_parameter = params[:row_parameter]
    data = sim.progress_overview_data(first_parameter, second_parameter)
    render json: data
  end

  def _sort
    params[:simulator].each_with_index do |sim_id, index|
      Simulator.find(sim_id).timeless.update_attribute(:position, index)
    end
    head :ok
  end

  def _host_parameters_field
    sim = Simulator.find(params[:id])
    host = Host.where(id: params[:host_id]).first
    render partial: "runs/host_parameter_fields", locals: {simulator: sim, host: host}
  end

  def _default_mpi_omp
    sim = Simulator.find(params[:id])
    host = Host.where(id: params[:host_id]).first
    mpi = sim.default_mpi_procs[host.id.to_s] || 1
    omp = sim.default_omp_threads[host.id.to_s] || 1
    data = {'mpi_procs' => mpi, 'omp_threads' => omp}
    render json: data
  end

  private
  def permitted_simulator_params
    params[:simulator].present? ? params.require(:simulator)
                                        .permit(:name,
                                                :pre_process_script,
                                                :local_pre_process_script,
                                                :command,
                                                :description,
                                                :executable_on_ids,
                                                :support_input_json,
                                                :support_omp,
                                                :support_mpi,
                                                :sequential_seed,
                                                :print_version_command,
                                                parameter_definitions_attributes: [[:id, :key, :type, :default, :description, :_destroy]],
                                                executable_on_ids: []
                                               ) : {}
  end
end
