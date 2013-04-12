class ParametersController < ApplicationController

  def show
    @parameter = Parameter.find(params[:id])
    @simulator = @parameter.simulator
    @parameter_keys = @simulator.parameter_keys.keys
    @runs = Run.where(parameter_id: @parameter).page(params[:page])
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @parameter }
    end
  end
end
