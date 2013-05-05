class RunsController < ApplicationController

  def show
    @run = Run.find(params[:id])
    @param_set = @run.parameter_set
    @analysis_runs = @run.analysis_runs
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @run }
    end
  end

  def create
    @param_set = ParameterSet.find(params[:parameter_set_id])
    @run = @param_set.runs.build(params[:run])
    respond_to do |format|
      if @run.save and @run.submit
        format.html { redirect_to @run, notice: 'Run was successfully created.' }
        format.json { render json: @run, status: :created, location: @run}
      else
        format.html { redirect_to @param_set, error: 'Failed to create a run.' }
        format.json { render json: @run.errors, status: :unprocessable_entity }
      end
    end
  end

end
