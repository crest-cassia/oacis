class AnalyzersController < ApplicationController

  def show
    @analyzer = Analyzer.find(params[:id])

    respond_to do |format|
      format.html
      format.json
    end
  end

  def new
    simulator = Simulator.find(params[:simulator_id])
    @analyzer = simulator.analyzers.build

    respond_to do |format|
      format.html
      format.json { render json: @analyzer }
    end
  end

  def edit
    @analyzer = Analyzer.find(params[:id])
  end

  def create
    simulator = Simulator.find(params[:simulator_id])
    @analyzer = simulator.analyzers.build(permitted_analyzer_params)

    respond_to do |format|
      if @analyzer.save
        format.html { redirect_to @analyzer, notice: 'Analyzer was successfully created.' }
        format.json { render json: @analyzer, status: :created, location: @analyzer }
      else
        format.html { render action: "new" }
        format.json { render json: @analyzer.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    @analyzer = Analyzer.find(params[:id])

    respond_to do |format|
      if @analyzer.update_attributes(permitted_analyzer_params)
        format.html { redirect_to @analyzer, notice: 'Analyzer was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @analyzer.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    analyzer = Analyzer.find(params[:id])
    simulator = analyzer.simulator
    analyzer.discard

    respond_to do |format|
      format.json { head :no_content }
      format.js
      format.html { redirect_to simulator_path(simulator) }
    end
  end

  # GET /analyzers/:id/_parameters_form
  def _parameters_form
    analyzer = Analyzer.find(params[:id])

    render partial: 'analyses/parameters_form', layout: false, locals: {analyzer: analyzer}
  end

  def _inner_show
    analyzer = Analyzer.find(params[:id])
    render partial: "inner_show", locals: {analyzer: analyzer}
  end

  def _host_parameters_field
    azr = Analyzer.find(params[:id])
    host = Host.where(id: params[:host_id]).first
    render partial: "analyses/host_parameter_fields", locals: {analyzer: azr, host: host}
  end

  def _default_mpi_omp
    azr = Analyzer.find(params[:id])
    host = Host.where(id: params[:host_id]).first
    host_id = host ? host.id.to_s : nil
    mpi = azr.default_mpi_procs[host_id] || 1
    omp = azr.default_omp_threads[host_id] || 1
    data = {'mpi_procs' => mpi, 'omp_threads' => omp}
    render json: data
  end

  private
  def permitted_analyzer_params
    return {} unless params[:analyzer].present?
    azr_params = params.require(:analyzer)
      .permit(:name,
              :type,
              :command,
              :description,
              :auto_run,
              :files_to_copy,
              :print_version_command,
              :simulator,
              :support_input_json,
              :support_mpi,
              :support_omp,
              :pre_process_script,
              :local_pre_process_script,
              :auto_run_submitted_to,
              :auto_run_host_group,
              parameter_definitions_attributes: [[:id, :key, :type, :default, :options, :description, :_destroy]],
              executable_on_ids: []
             )
    if submitted_to_is_host_group?(azr_params)
      azr_params[:auto_run_host_group] = azr_params[:auto_run_submitted_to]
      azr_params[:auto_run_submitted_to] = nil
    end
    azr_params
  end

  def submitted_to_is_host_group?(azr_params)
    host_id = azr_params[:auto_run_submitted_to]
    host_id.present? && HostGroup.where(id: host_id).present?
  end
end
