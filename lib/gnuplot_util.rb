module GnuplotUtil

  def self.script_for_single_line_plot(data, xlabel = nil, ylabel = nil, error_bar = false)
    script = "unset key\n"
    script += "set xlabel \"#{xlabel}\"\n" if xlabel
    script += "set ylabel \"#{ylabel}\"\n" if ylabel

    data_string = ""
    commands = []

    if error_bar
      commands += ["'-' u 1:2:3 w yerrorbars ls 1",
                   "'-' u 1:2 w lines ls 1"]
      data_string += convert_to_csv(data) * 2 # need to be written twice
    else
      commands += ["'-' u 1:2 w linespoints"]
      data_string += convert_to_csv(data)
    end
    script += "plot " + commands.join(', ') + "\n"
    script + data_string
  end

  def self.script_for_multi_line_plot(data_arr, xlabel = nil, ylabel = nil, error_bar = false,
                                        series = nil, series_values = [])
    script = series.present? ? "set key\n" : "unset key\n"
    script += "set xlabel \"#{xlabel}\"\n" if xlabel
    script += "set ylabel \"#{ylabel}\"\n" if ylabel

    data_string = ""
    commands = []

    data_arr.each_with_index do |data, idx|
      ls_idx = idx + 1
      title = idx == 0 ? "#{series} = #{series_values[idx]}" : "#{series_values[idx]}"
      if error_bar
        commands += ["'-' u 1:2:3 w yerrorbars ls #{ls_idx} title '#{title}'",
                     "'-' u 1:2 w lines ls #{ls_idx} notitle"]
        data_string += convert_to_csv(data) * 2 # need to be written twice
      else
        commands += ["'-' u 1:2 w linespoints title '#{title}'"]
        data_string += convert_to_csv(data)
      end
    end
    script += "plot " + commands.join(', ') + "\n"
    script + data_string
  end

  private
  def self.convert_to_csv(data)
    data.map do |row|
      row.map {|val| val ? val : 0}.join(' ')
    end.join("\n") + "\ne\n"
  end
end
