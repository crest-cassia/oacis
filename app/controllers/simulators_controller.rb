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
    @param_sets = ParameterSet.where(:simulator_id => @simulator).page(params[:page])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @simulator }
    end
  end

  # GET /simulators/new
  # GET /simulators/new.json
  # def new
  #   @simulator = Simulator.new

  #   respond_to do |format|
  #     format.html # new.html.erb
  #     format.json { render json: @simulator }
  #   end
  # end

  # GET /simulators/1/edit
  # def edit
  #   @simulator = Simulator.find(params[:id])
  # end

  # POST /simulators
  # POST /simulators.json
  # def create
  #   @simulator = Simulator.new(params[:simulator])

  #   respond_to do |format|
  #     if @simulator.save
  #       format.html { redirect_to @simulator, notice: 'Simulator was successfully created.' }
  #       format.json { render json: @simulator, status: :created, location: @simulator }
  #     else
  #       format.html { render action: "new" }
  #       format.json { render json: @simulator.errors, status: :unprocessable_entity }
  #     end
  #   end
  # end

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
end
