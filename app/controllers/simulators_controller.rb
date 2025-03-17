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
    @filter = nil
    if params[:filter]
      @filter = @simulator.parameter_set_filters.where(id: params[:filter]).first
      if @filter.nil?
        flash[:alert] = "Filter #{params[:filter]} is not found"
      end
    elsif params[:q]
      q = JSON.load(params[:q])
      if q.present?
        @filter = @simulator.parameter_set_filters.build(conditions: q)
        unless @filter.valid?
          flash[:alert] = "invalid filter parameter: #{q.inspect}"
          @filter = nil
        end
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
    if @simulator.executable_on.empty? and h = Host.first
      @simulator.executable_on.push h
    end
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

  # GET /simulators/:id/export_runs.csv
  def export_runs
    @simulator = Simulator.find(params[:id])
    respond_to do |format|
      # format.csv { send_data @simulator.runs_csv, type: "text", disposition: 'inline' }
      format.csv { send_data @simulator.runs_csv, filename: "runs_#{@simulator.name}.csv", type: "text/csv", disposition: 'inline' }
    end
  end

  # POST /simulators/:_id/save_filter redirect_to simulators#show
  def save_filter
    simulator = Simulator.find(params[:id])
    name = params[:filter_name]
    filter = simulator.parameter_set_filters.where(name: name).first
    if filter
      filter.conditions = JSON.load(params[:q])
      msg = "Filter '#{name}' was updated."
    else
      filter = simulator.parameter_set_filters.build(name: name, conditions: JSON.load(params[:q]))
      msg = "Filter was saved as '#{name}'."
    end
    if filter.save
      flash[:notice] = msg
      redirect_to simulator_path(simulator, filter: filter.id)
    else
      flash[:alert] = "Failed to save Filter: #{filter.errors.messages}"
      redirect_back(fallback_location: simulator)
    end
  end

  # PATCH /simulators/:_id/update_filter redirect_to simulators#show
  def update_filter
    simulator = Simulator.find(params[:id])
    filter = simulator.parameter_set_filters.find(params[:filter])
    if filter.update(name: params[:filter_name], conditions: JSON.load(params[:conditions]))
      flash[:notice] = "Filter '#{filter.name}' was updated."
    else
      flash[:alert] = "Failed to update Filter: #{filter.errors.messages}"
    end

    redirect_back(fallback_location: simulator)
  end

  def _find_filter
    simulator = Simulator.find(params[:id])
    name = params[:filter_name]
    filter = simulator.parameter_set_filters.where(name: name).first
    render json: filter
  end

  def _delete_filter
    simulator = Simulator.find(params[:id])
    simulator.parameter_set_filters.where(id: params[:filter]).first&.destroy
    head :ok
  end

  def _parameter_sets_list
    simulator = Simulator.find(params[:id])
    parameter_sets = simulator.parameter_sets
    if params[:q] && c = JSON.load(params[:q])
      q = simulator.parameter_set_filters.build(conditions: c)
      parameter_sets = q.parameter_sets
    end
    keys = simulator.parameter_definitions.map {|pd| pd.key }
    num_ps_total = simulator.parameter_sets.count
    render json: ParameterSetsListDatatable.new(parameter_sets, keys, view_context, num_ps_total)
  end

  def _analyzer_list
    render json: AnalyzersListDatatable.new(view_context)
  end

  def _parameter_set_filters_list
    simulator = Simulator.find(params[:id])
    filters = simulator.parameter_set_filters
    render json: ParameterSetFiltersListDatatable.new(filters, simulator, view_context, filters.count)
  end

  def _number_of_runs
    sim = Simulator.find(params[:id])
    stat_count = sim.runs_status_count
    data = { stat_count: stat_count, total: stat_count.values.inject(:+) }
    render json: data
  end

  def _progress_overview
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
    sim = Simulator.find(params[:id])
    sim.save_tasks.where(cancel_flag: false).each do |t|
      t.update_attribute(:cancel_flag, true)
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
                                                parameter_definitions_attributes: [[:id, :key, :type, :default, :options, :description, :_destroy]],
                                                executable_on_ids: []
                                               ) : {}
  end
end
