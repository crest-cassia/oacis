set term postscript eps enhanced color
set output "sample.eps"
plot "_input/time_series.dat" w l using 1:2 t "signal1", "_input/time_series.dat" w l using 1:3 t "signal2"