require 'spec_helper'

describe GnuplotUtil do 

  describe ".script_for_single_line_plot" do

    it "returns a gnuplot script to draw a single line plot" do
      data = [[0,1,0.1], [1,2,0.2]]
      expected = <<-EOS
unset key
set xlabel "XXX"
set ylabel "YYY"
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
unset key
set xlabel "XXX"
set ylabel "YYY"
plot '-' u 1:2:3 w yerrorbars ls 1, '-' u 1:2 w lines ls 1
0 1 0.1
1 2 0.2
e
0 1 0.1
1 2 0.2
e
EOS
      GnuplotUtil.script_for_single_line_plot(data, "XXX", "YYY", true).should eq expected
    end

    it "plots correctly even when third column is nil" do
      data = [[0,1,0.1,"aaa"], [1,2,nil,"bbb"]]
      expected = <<-EOS
unset key
set xlabel "XXX"
set ylabel "YYY"
plot '-' u 1:2:3 w yerrorbars ls 1, '-' u 1:2 w lines ls 1
0 1 0.1 aaa
1 2 0 bbb
e
0 1 0.1 aaa
1 2 0 bbb
e
EOS
      GnuplotUtil.script_for_single_line_plot(data, "XXX", "YYY", true).should eq expected
    end
  end

  describe ".script_for_multi_line_plot" do

    it "returns a gnuplot script to draw a series of plots" do
      data_arr = [
        [[0,1,0.1], [1,2,0.2]],
        [[0,3,0.3], [1,4,0.4]]
      ]
      expected = <<-EOS
set key
set xlabel "XXX"
set ylabel "YYY"
plot '-' u 1:2 w linespoints title 'ZZZ = 5', '-' u 1:2 w linespoints title '4'
0 1 0.1
1 2 0.2
e
0 3 0.3
1 4 0.4
e
      EOS
      GnuplotUtil.script_for_multi_line_plot(data_arr, "XXX", "YYY", false, "ZZZ", [5, 4]).should eq expected
    end

    it "returns a gnuplot script to draw a series of plots with errorbars when option is given" do
      data_arr = [
        [[0,1,0.1], [1,2,0.2]],
        [[0,3,0.3], [1,4,0.4]]
      ]
      expected = <<-EOS
set key
set xlabel "XXX"
set ylabel "YYY"
plot '-' u 1:2:3 w yerrorbars ls 1 title 'ZZZ = 5', '-' u 1:2 w lines ls 1 notitle, '-' u 1:2:3 w yerrorbars ls 2 title '4', '-' u 1:2 w lines ls 2 notitle
0 1 0.1
1 2 0.2
e
0 1 0.1
1 2 0.2
e
0 3 0.3
1 4 0.4
e
0 3 0.3
1 4 0.4
e
      EOS
      GnuplotUtil.script_for_multi_line_plot(data_arr, "XXX", "YYY", true, "ZZZ", [5, 4]).should eq expected
    end
  end
end
