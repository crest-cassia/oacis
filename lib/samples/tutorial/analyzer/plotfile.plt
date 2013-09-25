set term postscript eps enhanced color
set output "sample.eps"
plot "_input/time_series.dat" u 1:2 w l t "signal1", "_input/time_series.dat" u 1:3 w l t "signal2"