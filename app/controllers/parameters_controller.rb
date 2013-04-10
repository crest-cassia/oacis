class ParametersController < ApplicationController

  def show
    @parameter = Parameter.find(params[:id])
    @simulator = @parameter.simulator
    @parameter_keys = @simulator.parameter_keys.keys
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @parameter }
    end
  end
end
