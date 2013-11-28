module GnuplotUtil

  def self.script_for_single_line_plot(data, xlabel = nil, ylabel = nil, error_bar = false)
    script = <<-EOS
set xlabel "#{xlabel}"
set ylabel "#{ylabel}"
unset key
    EOS

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
end
