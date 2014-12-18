class SimulatorsController < ApplicationController
  # GET /simulators
  # GET /simulators.json
  def index
    @simulators = Simulator.asc(:position).all
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

  # GET /simulators/1/duplicate
  def duplicate
    @duplicating_simulator = Simulator.find(params[:id])
    @copied_analyzers = @duplicating_simulator.analyzers
    @simulator = @duplicating_simulator.clone
    render :new
  end

  # GET /simulators/1/edit
  def edit
    @simulator = Simulator.find(params[:id])
  end

  # POST /simulators
  # POST /simulators.json
  def create
    @simulator = Simulator.new(params[:simulator])
    if params[:duplicating_simulator]
      @duplicating_simulator = Simulator.find(params[:duplicating_simulator])
      @copied_analyzers = params[:copied_analyzers].to_a.map {|azr_id| Analyzer.find(azr_id) }
      @copied_analyzers.each do |azr|
        @simulator.analyzers.push azr.clone
      end
    end

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

  def _analyzer_list
    render json: AnalyzersListDatatable.new(view_context)
  end

  def _progress
    sim = Simulator.find(params[:id])
    first_parameter = params[:column_parameter]
    second_parameter = params[:row_parameter]
    data = sim.progress_overview_data(first_parameter, second_parameter)
    render json: data
  end

  def explorer
    @simulator = Simulator.find(params[:id])
    @param_set = @simulator.parameter_sets.first

    respond_to do |format|
      format.html
    end
  end

  def _sort
    params[:simulator].each_with_index do |sim_id, index|
      Simulator.find(sim_id).timeless.update_attribute(:position, index)
    end
    render nothing: true
  end

  def _host_parameters_field
    sim = Simulator.find(params[:id])
    host = Host.where(id: params[:host_id]).first
    render partial: "runs/host_parameter_fields", locals: {sim: sim, host: host}
  end
end
