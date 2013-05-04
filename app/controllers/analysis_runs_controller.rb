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
    @run = Run.find(params[:run_id])
    azr = @run.simulator.analyzers.find(params[:analysis_run][:analyzer])
    arn = @run.analysis_runs.build(analyzer: azr, parameters: params[:parameters])

    respond_to do |format|
      if arn.save and arn.submit
        format.html { redirect_to run_analysis_run_path(@run, arn),
                      notice: "AnalysisRun was successfully created."}
        format.json { render json: @arn, status: :created, location: @arn}
      else
        # UPDATE ME: a tentative implementation
        format.html { redirect_to @run, alert: "Failed to create analysis run" }
        format.json { render json: @arn.errors, status: :unprocessable_entity}
      end
    end
  end
end
