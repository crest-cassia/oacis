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

  # GET /simulators/:simulator_id/analyzers/:id/_parameters_form
  def _parameters_form
    simulator = Simulator.find(params[:simulator_id])
    analyzer = simulator.analyzers.find(params[:id])
    param_def = analyzer.parameter_definitions

    render partial: 'shared/parameters_form', layout: false, locals: {param_def: param_def}
  end
end
