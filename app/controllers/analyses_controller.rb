class AnalysesController < ApplicationController

  def show
    @analysis = Analysis.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @analysis }
    end
  end

  def create
    analyzable = fetch_analyzable(params)
    azr = analyzable.simulator.analyzers.find(params[:analysis][:analyzer])
    host_id = params[:analysis]["submitted_to"]
    host = host_id.present? ? Host.find(host_id) : nil
    permitted_params = permitted_analysis_params(azr, host)
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
    anl.destroy

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
    stat = params[:analysis_status].to_sym
    render json: AnalysesListDatatable.new(Analysis.where(status: stat), view_context)
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

  def permitted_analysis_params(azr, host)
    analysis_param_keys = azr.parameter_definitions.map {|pd| pd.key.to_sym }
    analysis_param_keys = {} if analysis_param_keys.empty?

    host_param_keys = {}
    host_param_keys = host.host_parameter_definitions.map {|hpd| hpd[:key] } if host

    params.require(:analysis).permit(
      :analyzer, :submitted_to, :mpi_procs, :omp_threads, :priority,
      host_parameters: host_param_keys,
      parameters: analysis_param_keys
      )
  end
end
