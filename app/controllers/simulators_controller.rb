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
    if params[:query_id].present?
      q = ParameterSetQuery.find(params[:query_id])
      parameter_sets = q.parameter_sets
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

  def _create_selected_runs
    param_set_ids_str = params[:ps_ids] || ""
    raise 'No parameter sets ware selected.' unless param_set_ids_str.present?
    param_set_ids = param_set_ids_str.split(",")
    num_runs = 1
    num_runs = params[:num_runs].to_i if params[:num_runs]
    raise 'params[:num_runs] is invalid' unless num_runs > 0
    @simulator = Simulator.find(params[:id])

    @runs = []
    run_params = permitted_run_params(params)
    param_set_ids.each do |ps_id|
      param_set = ParameterSet.where(id: ps_id).first
      next unless param_set.present?
      num_runs.times do |i|
        run = param_set.runs.build(run_params)
        @runs << run if run.save
      end
    end

    if @runs.present?
      flash[:notice] = "#{@runs.size} run#{@runs.size > 1 ? 's were' : ' was'} successfully created"
    else
      flash[:alert] = "No runs were created"
    end
    redirect_to @simulator
  end

  def _delete_selected_parameter_sets
    selected_ps_ids_str = params[:id_list] || ""
    selected_ps_ids = selected_ps_ids_str.split(",")
    @simulator = Simulator.find(params[:id])
    
    cnt = 0
    selected_ps_ids.each do |ps_id|
      ps = @simulator.parameter_sets.where(id: ps_id).first
      if ps.present?
        ps.discard
        cnt = cnt + 1
      end
    end

    
    if cnt == selected_ps_ids.size
      flash[:notice] = "#{cnt} parameter set#{cnt > 1 ? 's were' : ' was'} successfully deleted"
    elsif cnt == 0
      flash[:alert] = "No parameter sets were deleted"
    else
      flash[:alert] = "#{cnt} parameter set#{cnt > 1 ? 's were' : ' was'} deleted (your request was #{selected_ps_ids.size} deletion)"
    end
    redirect_to @simulator
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

  def permitted_run_params(params)
    if params[:run].present?
      if params[:run]["submitted_to"].present?
        id = params[:run]["submitted_to"]
        if Host.where(id: id).exists?
          host_param_keys = Host.find(id).host_parameter_definitions.map(&:key)
          params.require(:run).permit(:mpi_procs, :omp_threads, :priority, :submitted_to, host_parameters: host_param_keys)
        elsif HostGroup.where(id: id).exists?
          modify_params_for_host_group_submission
          params.require(:run).permit(:mpi_procs, :omp_threads, :priority, :host_group)
        end
      else
        raise "submitted_to is a required parameter"
      end
    else
      raise "'run' is a required parameter"
    end
  end
end
