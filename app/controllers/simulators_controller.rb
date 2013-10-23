class SimulatorsController < ApplicationController
  # GET /simulators
  # GET /simulators.json
  def index
    @simulators = Simulator.all
    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @simulators }
    end
  end

  # GET /simulators/1
  # GET /simulators/1.json
  def show
    @simulator = Simulator.find(params[:id])
    @analyzers = @simulator.analyzers
    @query_id = params[:query_id]

    if @simulator.parameter_set_queries.present?
      @query_list = {}
      @simulator.parameter_set_queries.each do |psq|
        @query_list[psq.query.to_s] = psq.id
      end
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @simulator }
    end
  end

  # GET /simulators/new
  # GET /simulators/new.json
  def new
    @simulator = Simulator.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @simulator }
    end
  end

  # GET /simulators/1/edit
  def edit
    @simulator = Simulator.find(params[:id])
  end

  # POST /simulators
  # POST /simulators.json
  def create
    @simulator = Simulator.new(params[:simulator])

    respond_to do |format|
      if @simulator.save
        format.html { redirect_to @simulator, notice: 'Simulator was successfully created.' }
        format.json { render json: @simulator, status: :created, location: @simulator }
      else
        format.html { render action: "new" }
        format.json { render json: @simulator.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /simulators/1
  # PUT /simulators/1.json
  def update
    @simulator = Simulator.find(params[:id])

    respond_to do |format|
      if @simulator.update_attributes(params[:simulator])
        format.html { redirect_to @simulator, notice: 'Simulator was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @simulator.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /simulators/1
  # DELETE /simulators/1.json
  def destroy
    @simulator = Simulator.find(params[:id])
    @simulator.destroy

    respond_to do |format|
      format.html { redirect_to simulators_url }
      format.json { head :no_content }
    end
  end

  # POST /simulators/:_id/_make_query redirect_to simulators#show
  def _make_query
    @query_id = params[:query_id]

    if params[:delete_query]
      @q = ParameterSetQuery.find(@query_id)
      @q.destroy
      @query_id = nil
    else
      @simulator = Simulator.find(params[:id])
      @new_query = @simulator.parameter_set_queries.build
      if @new_query.set_query(params["query"]) and @new_query.save
        @query_id = @new_query.id
        flash[:notice] = "A new query is created"
      else
        flash[:alert] = "Failed to create a query"
      end
    end

    redirect_to  :action => "show", :query_id => @query_id
  end

  def _parameters_list
    simulator = Simulator.find(params[:id])
    parameter_sets = simulator.parameter_sets
    if params[:query_id].present?
      q = ParameterSetQuery.find(params[:query_id])
      parameter_sets = q.parameter_sets
    end
    keys = simulator.parameter_definitions.map {|pd| pd.key }
    render json: ParameterSetsListDatatable.new(parameter_sets, keys, view_context)
  end

  def _parameter_sets_status_count
    render json: Simulator.only("parameter_sets.runs.status").find(params[:id]).parameter_sets_status_count.to_json
  end

  def _analyzer_list
    render json: AnalyzersListDatatable.new(view_context)
  end

  def _progress
    sim = Simulator.find(params[:id])
    column_parameter = params[:column_parameter]
    row_parameter = params[:row_parameter]
    parameters = [column_parameter, row_parameter]
    parameter_values = [
      sim.parameter_sets.distinct("v.#{column_parameter}").sort,
      sim.parameter_sets.distinct("v.#{row_parameter}").sort
    ]
    num_runs = parameter_values[1].map do |p2|
      parameter_values[0].map do |p1|
        if row_parameter == column_parameter and p1 != p2
          [0,0]
        else
          parameter_sets = ParameterSet.where({
            :simulator => sim,
            "v.#{column_parameter}" => p1,
            "v.#{row_parameter}" => p2
          })
          parameter_sets.inject([0,0]) do |sum, ps|
            sum[0] += ps.runs.where(status: :finished).count
            sum[1] += ps.runs.count
            sum
          end
        end
      end
    end

    progress_overview = {
      parameters: parameters,
      parameter_values: parameter_values,
      num_runs: num_runs
    }
    render json: progress_overview
  end

  def plottable
    simulator = Simulator.find(params[:id])

    run = Run.where(simulator: simulator, status: :finished).first
    list = plottable_keys(run.try(:result)).map {|key| ".#{key}" }

    simulator.analyzers.each do |azr|
      anl = azr.analyses.where(status: :finished).first
      keys = plottable_keys(anl.try(:result)).map do |key|
        "#{azr.name}.#{key}"
      end
      list += keys
    end

    respond_to do |format|
      format.json { render json: list }
    end
  end

  private
  def plottable_keys(result)
    ret = []
    if result.is_a?(Hash)
      result.each_pair do |key, val|
        if val.is_a?(Numeric)
          ret << key
        elsif val.is_a?(Hash)
          ret += plottable_keys(val).map {|x| "#{key}.#{x}" }
        end
      end
    end
    ret
  end

  public
  def distinct
    simulator = Simulator.find(params[:id])
    distinct_parameters = {}
    simulator.parameter_definitions.each do |pd|
      key = pd.key
      values = simulator.parameter_sets.distinct("v.#{key}").sort
      distinct_parameters[key] = values
    end

    respond_to do |format|
      format.json { render json: distinct_parameters}
    end
  end
end
