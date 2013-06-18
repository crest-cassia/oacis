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
    @params_key_count = @simulator.params_key_count

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
  # def edit
  #   @simulator = Simulator.find(params[:id])
  # end

  # POST /simulators
  # POST /simulators.json
  def create
    param_def = {}
    if params.has_key?(:definitions)
      params[:definitions].each do |defn|
        name = defn[:name]
        next if name.empty?
        param_def[name] = {}
        param_def[name]["type"] = defn["type"]
        param_def[name]["default"] = defn["default"]
        param_def[name]["description"] = defn["description"]
      end
    end
    @simulator = Simulator.new(params[:simulator])
    @simulator.parameter_definitions = param_def
    @simulator.support_input_json = ParametersUtil.boolean(params[:simulator]["support_input_json"])

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
  # def update
  #   @simulator = Simulator.find(params[:id])

  #   respond_to do |format|
  #     if @simulator.update_attributes(params[:simulator])
  #       format.html { redirect_to @simulator, notice: 'Simulator was successfully updated.' }
  #       format.json { head :no_content }
  #     else
  #       format.html { render action: "edit" }
  #       format.json { render json: @simulator.errors, status: :unprocessable_entity }
  #     end
  #   end
  # end

  # DELETE /simulators/1
  # DELETE /simulators/1.json
  # def destroy
  #   @simulator = Simulator.find(params[:id])
  #   @simulator.destroy

  #   respond_to do |format|
  #     format.html { redirect_to simulators_url }
  #     format.json { head :no_content }
  #   end
  # end

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
    render json: ParameterSetsListDatatable.new(view_context)
  end

  def _parameter_sets_status_count
    render json: Simulator.only("parameter_sets.runs.status").find(params[:id]).parameter_sets_status_count.to_json
  end
end
