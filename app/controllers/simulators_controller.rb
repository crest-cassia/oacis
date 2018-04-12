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
    save_tasks = SaveTask.where({cancel_flag: false})
    @ps_creation_size = save_tasks.inject(0) {|sum,t| sum + t.creation_size }
   
    @filter_set_name = "Not filtering." 
    if params[:filter_set_name].present?
      @filter_set_name = params[:filter_set_name]
    end
    
    @filter_hash = {}
    if params[:filter_json].present?
      @filter_hash = JSON.parse(params[:filter_json].to_s)
    end

    @filter_set_query_array = []
    if @filter_hash.present?
      len = 0
      continue_flg = false
      @filter_hash.each do |filter|
        next unless filter["enable"] && filter["query"].present? && filter["query"].to_s.length > 0
        @filter_set_query_array << filter["query"]
      end
    end

    if params[:isLoaded].present?
      @isLoaded = params[:isLoaded]
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
    simulator = Simulator.find(params[:id])
    if simulator.filter_sets.present?
      filter_sets = simulator.filter_sets
      total_count = filter_sets.count
    else
      total_count = 0
    end
    render json: FilterSetListDatatable.new(filter_sets, simulator, view_context, total_count)
  end

  # /simulator/:id/_parameter_set_filter_list
  def _parameter_set_filter_list
    count = 0
    bExist = true
    if params[:filter_json].present? && params[:filter_json] != "undefined"
      filter_list = JSON.parse(params[:filter_json])
      a = []
      filter_list.each_with_index do |fl, i|
        h = {}
        h[:enable] = fl["enable"]
        if fl["query"] == ''
          bExist = false
        else
          h[:query] = fl["query"]
          a << h
          count = i
        end
      end
      filter_list = a
    elsif params[:filter_set_id].present? && params[:filter_set_id] != "undefined"
      simulator = Simulator.find(params[:id])
      fs = simulator.filter_sets.find(params[:filter_set_id])
      fl = ParameterSetFilter.where({"filter_set_id": params[:filter_set_id]})

      a = []
      fl.each_with_index do |f, i|
        h = {}
        h[:enable] = f.enable
        h[:query] = ParametersUtil.parse_query_hash_to_str(f.query, simulator)
        a << h
        count = i
      end
      filter_list = a
    else
      bExist = false
    end
    render json: FilterListDatatable.new(filter_list, count, view_context, bExist)
  end

  # POST /simulators/:_id/_save_filter_set
  def _save_filter_set
    filters_str = params[:filter_query_array]
    filters = JSON.parse(filters_str)
    @simulator = Simulator.find(params[:id])
    fs = @simulator.filter_sets.where(name: params[:name])
    if fs.exists?
      fs.destroy()
    end
    @new_filter_set = @simulator.filter_sets.build
    @new_filter_set.name = params[:name]
    @new_filter_set.save

    new_filters = []
    filters.each_with_index do |param, i|
      filter_hash = ParametersUtil.parse_query_str_to_hash(param["query"])
      filter_hash['enable'] = param["enable"]
      new_filters << @new_filter_set.parameter_set_filters.build
      new_filters[i].simulator = @simulator
      new_filters[i].filter_set = @new_filter_set
      new_filters[i].set_one_query(filter_hash)
    end

    if new_filters.map(&:save)
      flash[:notice] = "A new filter set is created or over writed."
    else
      flash[:notice] = "Failed to create a filter set."
    end

  end

  def _delete_filter_set
    @simulator = Simulator.find(params[:id])
    fs = @simulator.filter_sets.where(name: params[:name])
    if fs.exists?
      fs.destroy()
    end
  end

  # POST /simulators/:_id/_set_filter_set redirect_to simulators#show
  def _set_filter_set
    filter_set_query = params[:filter_set_query_for_set]
    filter_hash = {}
    if filter_set_query.present?
      filter_hash = JSON.parse(filter_set_query)
    end
    @filter_hash = filter_hash
    redirect_to  :action => "show", :filter_json => filter_hash.to_json, :filter_set_name => params[:filter_set_name_for_set], :isLoaded => params[:isLoaded]
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

    if params[:filter_hash].present?
      filter_hash = params[:filter_hash]
      filter_hash.each do |filter|
        next unless filter[:enable] == "true"
        a = filter[:query].split(' ');
        next if a.length != 3
        h = {}
        pd = simulator.parameter_definition_for(a[0])
        unless FilterSet.supported_matcher_str(pd.type).include?(a[1])
          rise "undefined matcher #{matcher} for #{type}"
        end
        matcher = ParametersUtil.get_operator(a[0], a[1], pd)
        if pd.type == "String"
          h["v.#{a[0]}"] = FilterSet.string_matcher_to_regexp(matcher, a[2])
        else
          val = 0

          if pd.type == "Integer" then
            val = a[2].to_i
          elsif pd.type == "Float" then
            val = a[2].to_f
          else
            val = false
            if a[2] == "true"
              val = true
            end
          end
          h["v.#{a[0]}"] = (matcher == "eq" ? val : {"$#{matcher}" => val} )
        end
        begin
          parameter_sets = parameter_sets.where(h)
          cnt = parameter_sets.count
        rescue => e
          message = "Error: #{e.message}"
          keys = simulator.parameter_definitions.map {|pd| pd.key }
          num_ps_total = simulator.parameter_sets.count
          render json: ParameterSetsListDatatable.new(simulator.parameter_sets, keys, view_context, num_ps_total, message) and return
        end
      end
    end

    keys = simulator.parameter_definitions.map {|pd| pd.key }
    num_ps_total = simulator.parameter_sets.count
    render json: ParameterSetsListDatatable.new(parameter_sets, keys, view_context, num_ps_total, "")
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

  def _cancel_create_ps
    save_tasks =  SaveTask.where({cancel_flag: false})
    save_tasks.each do |t|
      t.cancel_flag = true
      t.save
    end
    redirect_to :action => "show"
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
