require 'spec_helper'

describe GnuplotUtil do 

  describe ".script_for_single_line_plot" do

    it "returns a gnuplot script to draw a single line plot" do
      data = [[0,1,0.1], [1,2,0.2]]
      expected = <<-EOS
set xlabel "XXX"
set ylabel "YYY"
unset key
plot '-' u 1:2 w linespoints
0 1 0.1
1 2 0.2
e
EOS
      GnuplotUtil.script_for_single_line_plot(data, "XXX", "YYY").should eq expected
    end

    it "returns a script to draw a single line plot with errorbars when option is given" do
      data = [[0,1,0.1], [1,2,0.2]]
      expected = <<-EOS
set xlabel "XXX"
set ylabel "YYY"
unset key
plot '-' u 1:2:3 w yerrorbars ls 1, '' u 1:2 w lines ls 1
0 1 0.1
1 2 0.2
e
0 1 0.1
1 2 0.2
e
EOS
      GnuplotUtil.script_for_single_line_plot(data, "XXX", "YYY", true).should eq expected
    end
  end
end
