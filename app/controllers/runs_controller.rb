class RunsController < ApplicationController

  def index
    respond_to do |format|
      format.html
    end
  end

  def _jobs_table
    stat = params["run_status"].to_sym
    render json: RunsListDatatable.new(Run.where(status: stat), view_context)
  end

  def check_server_status
    Resque.enqueue(JobObserver)
    Resque.enqueue(JobSubmitter)
    render nothing: true
  end

  def show
    @run = Run.find(params[:id])
    @param_set = @run.parameter_set
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @run }
    end
  end

  def create
    if params[:preview_button]
      preview
      return
    end

    @param_set = ParameterSet.find(params[:parameter_set_id])

    num_runs = 1
    num_runs = params[:num_runs].to_i if params[:num_runs]
    raise 'params[:num_runs] is invalid' unless num_runs > 0

    @runs = []
    num_runs.times do |i|
      run = @param_set.runs.build(params[:run])
      @runs << run if run.save
    end

    respond_to do |format|
      if @runs.present?
        Resque.enqueue(JobSubmitter)
        message = "#{@runs.count} run#{@runs.size > 1 ? 's were' : ' was'} successfully created"
        format.json { render json: @runs, status: :created, location: @param_set}
        @messages = {success: [message]}
        format.js
      else
        format.json {
          render json: @runs.map{ |r| r.errors }, status: :unprocessable_entity
        }
        run = @param_set.runs.build(params[:run])
        run.valid?
        @messages = {error: run.errors.full_messages }
        format.js
      end
    end
  end

  def _analyses_list
    run = Run.find(params[:id])
    render json: AnalysesListDatatable.new(view_context, run.analyses)
  end

  def preview
    param_set = ParameterSet.find(params[:parameter_set_id])
    run = param_set.runs.build(params[:run])
    @error_messages = run.valid? ? [] : run.errors.full_messages
    @script = JobScriptUtil.script_for(run, run.submitted_to) if run.valid? and run.submitted_to?
    respond_to do |format|
      format.js {
        render action: "preview"
      }
    end
  end

  def destroy
    @run = Run.find(params[:id])
    @run.destroy

    respond_to do |format|
      format.json { head :no_content }
      format.js
    end
  end
end
