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
      expect(GnuplotUtil.script_for_single_line_plot(data, "XXX", "YYY")).to eq expected
    end

    it "returns a script to draw a single line plot with errorbars when option is given" do
      data = [[0,1,0.1], [1,2,0.2]]
      expected = <<-EOS
unset key
set xlabel "XXX"
set ylabel "YYY"
plot '-' u 1:2:3 w errorlines
0 1 0.1
1 2 0.2
e
EOS
      expect(GnuplotUtil.script_for_single_line_plot(data, "XXX", "YYY", true)).to eq expected
    end

    it "plots correctly even when third column is nil" do
      data = [[0,1,0.1,"aaa"], [1,2,nil,"bbb"]]
      expected = <<-EOS
unset key
set xlabel "XXX"
set ylabel "YYY"
plot '-' u 1:2:3 w errorlines
0 1 0.1 aaa
1 2 0 bbb
e
EOS
      expect(GnuplotUtil.script_for_single_line_plot(data, "XXX", "YYY", true)).to eq expected
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
      expect(GnuplotUtil.script_for_multi_line_plot(data_arr, "XXX", "YYY", false, "ZZZ", [5, 4])).to eq expected
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
plot '-' u 1:2:3 w errorlines title 'ZZZ = 5', '-' u 1:2:3 w errorlines title '4'
0 1 0.1
1 2 0.2
e
0 3 0.3
1 4 0.4
e
      EOS
      expect(GnuplotUtil.script_for_multi_line_plot(data_arr, "XXX", "YYY", true, "ZZZ", [5, 4])).to eq expected
    end
  end
end
