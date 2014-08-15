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
      if arn.save
        format.json { render json: arn, status: :created, location: arn}
        format.js
      else
        # UPDATE ME: a tentative implementation
        format.html { redirect_to analyzable, alert: "Failed to create analysis" }
        format.json { render json: arn.errors, status: :unprocessable_entity}
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
    arn = Analysis.find(params[:id])
    render partial: "shared/results", layout: false, locals: {result: arn.result, result_paths: arn.result_paths, archived_result_path: nil}
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

  def after_create_redirect_path(arn)
    case arn.analyzer.type
    when :on_parameter_set
      ps = arn.analyzable
      parameter_set_path(ps, anchor: '!tab-analyses')
    when :on_run
      run = arn.analyzable
      run_path(run, anchor: '!tab-analyses')
    else
      raise "must not happen"
    end
  end
end
