class AnalyzersController < ApplicationController

  def show
    @analyzer = Analyzer.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @analyzers }
    end
  end

  def new
    simulator = Simulator.find(params[:simulator_id])
    @analyzer = simulator.analyzers.build

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @analyzer }
    end
  end

  def edit
    @analyzer = Analyzer.find(params[:id])
  end

  def create
    simulator = Simulator.find(params[:simulator_id])
    @analyzer = simulator.analyzers.build(params[:analyzer])

    respond_to do |format|
      if @analyzer.save
        format.html { redirect_to @analyzer, notice: 'Analyzer was successfully created.' }
        format.json { render json: @analyzer, status: :created, location: @analyzer }
      else
        format.html { render action: "new" }
        format.json { render json: @analyzer.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    @analyzer = Analyzer.find(params[:id])

    respond_to do |format|
      if @analyzer.update_attributes(params[:analyzer])
        format.html { redirect_to @analyzer, notice: 'Analyzer was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @analyzer.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    analyzer = Analyzer.find(params[:id])
    simulator = analyzer.simulator
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
