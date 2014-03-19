require 'json'
require 'gnuplot'
require 'csv'

def load_data
  if File.exist?('_input.json')
    io = File.open('_input.json', 'r')
    return JSON.load(io)
  else
    return nil
  end
end

def save_data(plot_data)
  # open for write
  CSV.generate("plot.csv") do |writer|
    plot_data.each do |a|
      writer << a
    end
  end
end

result = load_data
unless result.nil?
  a =   result["result"]["data"]["best"].map.with_index(1) {|itr, i| [i, itr["output"][0]]}
  save_data(a)

  x = a.map{|val| val[0]}
  y = a.map{|val| val[1]}

  Gnuplot.open do |gp|
    Gnuplot::Plot.new( gp ) do |plot|
      plot.yrange "[0:2.5]"
      plot.xlabel "iteration"
      plot.ylabel "fitness"
      plot.title  "iteration-fitness plot"
      plot.terminal "postscript 16 color"
      plot.output "plot.eps"
      plot.set 'isosamples 50.50'
      data = [ x, y ]
      plot.data << Gnuplot::DataSet.new( data ) do |ds|
        ds.with = "lines"
        ds.title = "best"
      end
    end
    Gnuplot::Plot.new( gp ) do |plot|
      plot.yrange "[0:2.5]"
      plot.xlabel "iteration"
      plot.ylabel "fitness"
      plot.title  "iteration-fitness plot"
      plot.terminal "jpeg 16"
      plot.output "plot.jpg"
      plot.set 'isosamples 50.50'
      data = [ x, y ]
      plot.data << Gnuplot::DataSet.new( data ) do |ds|
        ds.with = "lines"
        ds.title = "best"
      end
    end
  end
end

