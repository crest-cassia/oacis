class ParameterSetsController < ApplicationController

  def show
    @param_set = ParameterSet.find(params[:id])
    @simulator = @param_set.simulator
    @parameter_keys = @simulator.parameter_definitions.keys
    @runs = Run.where(parameter_set_id: @param_set).page(params[:page])
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @param_set }
    end
  end
end
