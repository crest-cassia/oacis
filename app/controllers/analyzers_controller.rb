class AnalyzersController < ApplicationController

  # GET /analyzers/:id
  # GET /analyzers/:id
  def show
    @analyzer = Analyzer.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @analyzers }
    end
  end

  def destroy
    simulator = Simulator.find(params[:simulator_id])
    analyzer = simulator.analyzers.find(params[:id])
    analyzer.destroy

    respond_to do |format|
      format.html { redirect_to simulator_url(simulator, anchor: '!tab-about') }
      format.json { head :no_content }
    end
  end

  # GET /analyzers/:id/_parameters_form
  def _parameters_form
    analyzer = Analyzer.find(params[:id])
    param_def = analyzer.parameter_definitions

    render partial: 'shared/parameters_form', layout: false, locals: {param_def: param_def}
  end
end
