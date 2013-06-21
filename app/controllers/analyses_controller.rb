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
    arn = analyzable.analyses.build(analyzer: azr, parameters: params[:parameters])

    respond_to do |format|
      if arn.save and arn.submit
        format.html { redirect_to analysis_path(arn),
                      notice: "Analysis was successfully created."}
        format.json { render json: arn, status: :created, location: arn}
      else
        # UPDATE ME: a tentative implementation
        format.html { redirect_to analyzable, alert: "Failed to create analysis run" }
        format.json { render json: arn.errors, status: :unprocessable_entity}
      end
    end
  end

  def _result
    arn = Analysis.find(params[:id])
    render partial: "shared/results", layout: false, locals: {result: arn.result, result_paths: arn.result_paths}
  end

  private
  def fetch_analyzable(params)
    analyzable = nil
    if params[:run_id]
      analyzable = Run.find(params[:run_id])
    elsif params[:parameter_set_id]
      analyzable = ParameterSet.find(params[:parameter_set_id])
    elsif params[:parameter_set_group_id]
      analyzable = ParameterSetGroup.find(params[:parameter_set_group_id])
    else
      raise "not supported type"
    end
    return analyzable
  end
end
