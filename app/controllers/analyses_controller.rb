class AnalysesController < ApplicationController

  def show
    @analysis = Analysis.find(params[:id])

    respond_to do |format|
      format.html
      format.json
    end
  end

  def create
    analyzable = fetch_analyzable(params)
    azr = analyzable.simulator.analyzers.find(params[:analysis][:analyzer])
    permitted_params = permitted_analysis_params(azr)
    anl = analyzable.analyses.build(permitted_params)
    respond_to do |format|
      if anl.save
        format.json { render json: anl, status: :created, location: anl}
        format.js
      else
        # UPDATE ME: a tentative implementation
        format.html { redirect_to analyzable, alert: "Failed to create analysis" }
        format.json { render json: anl.errors, status: :unprocessable_entity}
      end
    end
  end

  def destroy
    anl = Analysis.find(params[:id])
    anl.discard

    respond_to do |format|
      format.json { head :no_content }
      format.js
    end
  end

  def _result
    @analysis = Analysis.find(params[:id])
    render partial: "attributes", layout: false
  end

  def _analyses_table
    stat = params[:analysis_status]
    render json: AnalysesListDatatable.new(Analysis.in(status: stat), view_context)
  end

  private
  def fetch_analyzable(params)
    analyzable = nil
    if params[:run_id]
      analyzable = Run.find(params[:run_id])
    elsif params[:parameter_set_id]
      analyzable = ParameterSet.find(params[:parameter_set_id])
    else
      raise "not supported type"
    end
    return analyzable
  end

  def after_create_redirect_path(anl)
    case anl.analyzer.type
    when :on_parameter_set
      ps = anl.analyzable
      parameter_set_path(ps, anchor: '!tab-analyses')
    when :on_run
      run = anl.analyzable
      run_path(run, anchor: '!tab-analyses')
    else
      raise "must not happen"
    end
  end

  def permitted_analysis_params(azr)
    found = find_host_or_host_group

    analysis_param_keys = azr.parameter_definitions.map {|pd| pd.key.to_sym }
    analysis_param_keys = {} if analysis_param_keys.empty?

    case found
    when Host
      host_param_keys = {}
      host_param_keys = found.host_parameter_definitions.map(&:key)

      params.require(:analysis).permit(
        :analyzer, :submitted_to, :mpi_procs, :omp_threads, :priority,
        host_parameters: host_param_keys,
        parameters: analysis_param_keys
      )
    when HostGroup
      params[:analysis][:host_group] = params[:analysis][:submitted_to]
      params.require(:analysis).permit(
        :analyzer, :host_group, :mpi_procs, :omp_threads, :priority,
        parameters: analysis_param_keys
      )
    else
      raise "must not happen" # manual submission was abolished
    end
  end

  def find_host_or_host_group
    host_id = params[:analysis][:submitted_to]
    if host_id.present?
      Host.where(id:host_id).exists? ? Host.find(host_id) : HostGroup.find(host_id)
    else
      nil
    end
  end
end
