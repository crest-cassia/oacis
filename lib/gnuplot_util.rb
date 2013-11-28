module GnuplotUtil

  def self.script_for_single_line_plot(data, xlabel = nil, ylabel = nil, error_bar = false)
    script = "unset key\n"
    script += "set xlabel \"#{xlabel}\"\n" if xlabel
    script += "set ylabel \"#{ylabel}\"\n" if ylabel

    if error_bar
      script += <<-EOS
plot '-' u 1:2:3 w yerrorbars ls 1, '-' u 1:2 w lines ls 1
      EOS
      script += data.map {|row| row.join(' ') }.join("\n") + "\ne\n"
      script += data.map {|row| row.join(' ') }.join("\n") + "\ne\n" # need to be written twice
    else
      script += <<-EOS
plot '-' u 1:2 w linespoints
      EOS
      script += data.map {|row| row.join(' ') }.join("\n") + "\ne\n"
    end

    script
  end

  def self.script_for_multiple_data_set(data_arr, xlabel = nil, ylabel = nil, error_bar = false,
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
        data_string += data.map {|row| row.join(' ') }.join("\n") + "\ne\n"
        data_string += data.map {|row| row.join(' ') }.join("\n") + "\ne\n" # need to be written twice
      else
        commands += ["'-' u 1:2 w linespoints title '#{title}'"]
        data_string += data.map {|row| row.join(' ') }.join("\n") + "\ne\n"
      end
    end
    script += "plot " + commands.join(', ') + "\n"
    script + data_string
  end
end
