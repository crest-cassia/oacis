class RunsController < ApplicationController

  def show
    @run = Run.find(params[:id])
    @parameter = @run.parameter
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @run }
    end
  end

  def create
    @parameter = Parameter.find(params[:parameter_id])
    @run = @parameter.runs.build(params[:run])
    respond_to do |format|
      if @run.save
        format.html { redirect_to @run, notice: 'Run was successfully created.' }
        format.json { render json: @run, status: :created, location: @run}
      else
        format.html { redirect_to @parameter, error: 'Failed to create a run.' }
        format.json { render json: @run.errors, status: :unprocessable_entity }
      end
    end
  end

end
