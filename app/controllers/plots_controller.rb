class PlotsController < ApplicationController

  def data
    base_ps = ParameterSet.find(params[:base_parameter_set])
    x_axis_key = params[:x_axis]
    analyzer = nil
    y_axis_keys = params[:y_axis].split('.')
    analyzer_name = y_axis_keys.shift
    if analyzer_name.present?
      analyzer = Analyzer.where(simulator: base_ps.simulator, name: analyzer_name).first
    end

    plot_data = []
    base_ps.parameter_sets_with_different(x_axis_key).each do |ps|
      if analyzer.nil?
        run = ps.runs.where(status: :finished).first
        result = run.result
        x = ps.v[x_axis_key]
        y = y_axis_keys.inject(result) {|y, y_key| y[y_key] }
        plot_data << [x, y]
      elsif analyzer.type == :on_parameter_set
        analysis = analyzer.analyses.where(analyzable: ps, status: :finished).first
        result = analysis.result
        # analysis = ps.analyses.where(analyzer: analyzer, status: :finished).first
        x = ps.v[x_axis_key]
        y = y_axis_keys.inject(result) {|y, y_key| y[y_key] }
        plot_data << [x, y]
      elsif analyzer.type == :on_run
        run_ids = ps.runs.where(status: :finished).map(&:id)
        analysis = analyzer.analyses.in(analyzable_id: run_ids).where(status: :finished).first
        result = analysis.result
        x = ps.v[x_axis_key]
        y = y_axis_keys.inject(result) {|y, y_key| y[y_key] }
        plot_data << [x, y]
      end
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
