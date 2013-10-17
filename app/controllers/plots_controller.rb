class PlotsController < ApplicationController

  def data
    base_ps = ParameterSet.find(params[:base_parameter_set])
    x_axis_key = params[:x_axis]
    analyzer = Analyzer.find(params[:analyzer])
    y_axis_keys = params[:y_axis].split('.')

    plot_data = []
    base_ps.parameter_sets_with_different(x_axis_key).each do |ps|
      analysis = ps.analyses.where(analyzer: analyzer, status: :finished).first
      x = ps.v[x_axis_key]
      y = analysis.result
      y_axis_keys.each {|y_key| y = y[y_key] }
      plot_data << [x, y]
    end

    respond_to do |format|
      format.json { render json: plot_data}
      format.csv {
        csv_string = plot_data.map {|d| d.join(',') }.join("\n")
        send_data csv_string, type: 'text/csv'
      }
    end
  end
end
