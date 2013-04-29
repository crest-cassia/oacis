class AnalyzersController < ApplicationController

  # GET /simulators/:simulator_id/analyzers/:id
  # GET /simulators/:simulator_id/analyzers/:id
  def show
    @simulator = Simulator.find(params[:simulator_id])
    @analyzer = @simulator.analyzers.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @analyzers }
    end
  end
end
