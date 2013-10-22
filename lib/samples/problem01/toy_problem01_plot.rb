require 'gnuplot'

Gnuplot.open do |gp|
  Gnuplot::SPlot.new( gp ) do |plot|
    plot.xrange "[-10:10]"
    plot.yrange "[-10:10]"
    plot.xlabel "parameter1"
    plot.ylabel "parameter2"
    plot.title  "toy_problem01"
    plot.terminal "postscript 16 color"
    plot.output "toy_problem01.eps"
    plot.set 'isosamples 50.50'
    data = "exp((-(x+4)**2-(y+4)**2)/50)+2.0*exp((-(x-5)**2-(y-5)**2)/10)"
    plot.data << Gnuplot::DataSet.new( data ) do |ds|
      ds.with = "pm3d"
    end
  end
  Gnuplot::SPlot.new( gp ) do |plot|
    plot.xrange "[-10:10]"
    plot.yrange "[-10:10]"
    plot.xlabel "parameter1"
    plot.ylabel "parameter2"
    plot.title  "toy_problem01"
    plot.terminal "jpeg 16"
    plot.output "toy_problem01.jpg"
    plot.set 'isosamples 50.50'
    data = "exp((-(x+4)**2-(y+4)**2)/50)+2.0*exp((-(x-5)**2-(y-5)**2)/10)"
    plot.data << Gnuplot::DataSet.new( data ) do |ds|
      ds.with = "pm3d"
    end
  end
end