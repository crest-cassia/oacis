class AnalysisRunsController < ApplicationController

  def show
    analyzable = fetch_analyzable(params)
    @analysis_run = analyzable.analysis_runs.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @analysis_run }
    end
  end

  def create
    analyzable = fetch_analyzable(params)
    azr = analyzable.simulator.analyzers.find(params[:analysis_run][:analyzer])
    arn = analyzable.analysis_runs.build(analyzer: azr, parameters: params[:parameters])

    respond_to do |format|
      if arn.save and arn.submit
        format.html { redirect_to analyzable_analysis_run_path(analyzable, arn),
                      notice: "AnalysisRun was successfully created."}
        format.json { render json: @arn, status: :created, location: @arn}
      else
        # UPDATE ME: a tentative implementation
        format.html { redirect_to @run, alert: "Failed to create analysis run" }
        format.json { render json: @arn.errors, status: :unprocessable_entity}
      end
    end
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

  def analyzable_analysis_run_path(analyzable, analysis_run)
    path = nil
    case analyzable
    when Run
      path = run_analysis_run_path(analyzable, analysis_run)
    when ParameterSet
      path = parameter_set_analysis_run_path(analyzable, analysis_run)
    else
      raise "not supported type"
    end
    return path
  end
end
