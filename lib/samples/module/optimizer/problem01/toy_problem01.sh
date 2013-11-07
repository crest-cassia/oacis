#!/bin/bash
C1=(-4 -4)
C2=(5 5)
V1=50.0
V2=10.0
VALUE=`echo "scale=6; e(-(( ($1-(${C1[0]}))^2 + ($2-(${C1[1]}))^2 )/$V1))+2.0*e(-(( ($1-(${C2[0]}))^2 + ($2-(${C2[1]}))^2 )/$V2))" | /usr/bin/bc -l`
if [ `echo $VALUE | cut -c 1` = "." ]
then
VALUE=0$VALUE
fi
/bin/echo "{\"Fitness\":[$VALUE]}" > _output.json
