class RunsController < ApplicationController

  def show
    @run = Run.find(params[:id])
    @parameter = @run.parameter
    @result_file_paths = Dir.glob(@run.dir.join('*'))
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @run }
    end
  end

  def create
    @parameter = Parameter.find(params[:parameter_id])
    @run = @parameter.runs.build(params[:run])
    respond_to do |format|
      if @run.save and @run.submit
        format.html { redirect_to @run, notice: 'Run was successfully created.' }
        format.json { render json: @run, status: :created, location: @run}
      else
        format.html { redirect_to @parameter, error: 'Failed to create a run.' }
        format.json { render json: @run.errors, status: :unprocessable_entity }
      end
    end
  end

end
