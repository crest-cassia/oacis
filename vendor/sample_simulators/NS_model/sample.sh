#!/bin/sh
#
# parameters
#  $1: Time
#  $2: Length of the lane
#  $3: V_max
#  $4: lambda
#  $5: 
RUN_PATH=`pwd`
BINARY_PATH=`pwd`
BINARY_NAME="traffic_NSmodel.out"
cd $RUN_PATH
#seed T Line_Length V_MAX Lambda --signal position cycle_term offset_time
${BINARY_PATH}/${BINARY_NAME} 123456 200 150 5 5 --signal 40 15 7 --signal 55 15 7 --signal 70 15 7 --signal 85 15 7
