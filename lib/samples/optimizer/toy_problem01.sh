#!/bin/sh
VALUE=`echo "scale=6; e(-(($1+10)^2)/10000.0)+e(-(($2-100)^2)/10000.0)+2.0*e(-(($1-50)^2)/10000.0)+2.0*e(-(($2-80)^2)/10000.0)" | /usr/bin/bc -l`
/bin/echo "{\"Fitness\":[$VALUE]}" > _output.json
