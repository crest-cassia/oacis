module MatplotlibUtil

  def self.script_for_single_line_plot(data, xlabel = nil, ylabel = nil, error_bar = false)
    sio = StringIO.new
    sio.puts "# %%"
    sio.puts "import numpy as np"
    sio.puts "import matplotlib.pyplot as plt", ""

    sio.puts "plt.xlabel(\"#{xlabel}\")" if xlabel
    sio.puts "plt.ylabel(\"#{ylabel}\")" if ylabel
    sio.puts ""

    x, y, yerr = to_arrays(data)
    # x = []
    # y = []
    # yerr = []
    # data.each do |row|
    #   x.push(row[0])
    #   y.push(row[1])
    #   yerr.push(row[2].to_f)  # yerr can be nil
    # end

    sio.puts "x = [#{x.join(', ')}]"
    sio.puts "y = [#{y.join(', ')}]"
    sio.puts "yerr = [#{yerr.join(', ')}]" if error_bar
    sio.puts ""

    if error_bar
      sio.puts "plt.errorbar(x, y, yerr=yerr)"
    else
      sio.puts "plt.plot(x, y)"
    end
    sio.puts "plt.show()"
    sio.string
  end

  def self.script_for_multi_line_plot(data_arr, xlabel = nil, ylabel = nil, error_bar = false,
                                        series = nil, series_values = [])
    sio = StringIO.new
    sio.puts "# %%"
    sio.puts "import numpy as np"
    sio.puts "import matplotlib.pyplot as plt", ""

    sio.puts "plt.xlabel(\"#{xlabel}\")" if xlabel
    sio.puts "plt.ylabel(\"#{ylabel}\")" if ylabel
    sio.puts ""

    data_arr.each_with_index do |data, idx|
      label = "#{series}=#{series_values[idx]}"
      x, y, yerr = to_arrays(data)

      sio.puts "# #{series} = #{series_values[idx]}"
      sio.puts "label = '#{label}'"
      sio.puts "x = [#{x.join(', ')}]"
      sio.puts "y = [#{y.join(', ')}]"
      sio.puts "yerr = [#{yerr.join(', ')}]" if error_bar
      sio.puts ""

      if error_bar
        sio.puts "plt.errorbar(x, y, yerr=yerr, label=label)"
      else
        sio.puts "plt.plot(x, y, label=label)"
      end
      sio.puts ""
    end
    sio.puts "plt.legend()"
    sio.puts "plt.show()"
    sio.string
  end

  def self.script_for_3d_scatter_plot(data, xlabel = nil, ylabel = nil, zlabel = nil)
    sio = StringIO.new
    sio.puts "# %%"
    sio.puts "import numpy as np"
    sio.puts "import matplotlib.pyplot as plt", ""

    sio.puts "fig = plt.figure()"
    sio.puts "ax = fig.add_subplot(projection='3d')", ""

    sio.puts "ax.set_xlabel(\"#{xlabel}\")" if xlabel
    sio.puts "ax.set_ylabel(\"#{ylabel}\")" if ylabel
    sio.puts "ax.set_zlabel(\"#{zlabel}\")" if zlabel
    sio.puts ""

    x = []
    y = []
    z = []
    data.each do |entry|
      x.push entry[0][xlabel]
      y.push entry[0][ylabel]
      z.push entry[1]
    end
    sio.puts "x = [#{x.join(', ')}]"
    sio.puts "y = [#{y.join(', ')}]"
    sio.puts "z = [#{z.join(', ')}]"
    sio.puts "ax.scatter(x, y, z)"
    sio.puts "plt.show()"

    sio.string
  end

  private
  def self.to_arrays(data)
    x = []
    y = []
    yerr = []
    data.each do |row|
      x.push(row[0])
      y.push(row[1])
      yerr.push(row[2].to_f)  # yerr can be nil
    end
    [x, y, yerr]
  end


end
