class AnalysisRunsController < ApplicationController

  def show
    if params[:parameter_set_id]
      @param_set = ParameterSet.find(params[:parameter_set_id])
      @simulator = @param_set.simulator
      @analysis_run = @param_set.analysis_runs.find(params[:id])
    elsif params[:run_id]
      @run = Run.find(params[:run_id])
      @param_set = @run.parameter_set
      @simulator = @param_set.simulator
      @analysis_run = @run.analysis_runs.find(params[:id])
    end
    @parameter_keys = @analysis_run.analyzer.parameter_definitions.keys

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @analysis_run }
    end
  end

  def create
  end
end
