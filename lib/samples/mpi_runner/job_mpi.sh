#!/bin/bash -x

#
#PJM --rsc-list "node=1"
#PJM --rsc-list "elapse=00:05:00"
#PJM --stg-transfiles all
#PJM --mpi "proc=16"
#PJM --stgin "rank=* ./sample_mpi %r:./"
#PJM --stgin "./_input.json ./"
#PJM --stgin "/home/uchitane/programm/c/cm/mpi_parallel_for_run ./"
#PJM -s
#
. /work/system/Env_base

mpiexec -n 16 /home/uchitane/program/c/cm/mpi_parallel_for_runs
#mpiexec -n 16 ./mpi_parallel_for_runs
