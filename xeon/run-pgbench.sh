#!/bin/bash

set -e

MACHINE=$1
BUILD=$2
OUTDIR=$3
DBNAME=$4
RUNS=$5
DURATION=$6
CLIENTS=$7
PARTITIONS=$8

for s in 10 100 1000; do

	for p in $PARTITIONS; do

		dropdb --if-exists $DBNAME >> $OUTDIR/debug.log 2>&1
		createdb $DBNAME >> $OUTDIR/debug.log 2>&1

		pgbench -i -s $s --partitions=$p $DBNAME >> $OUTDIR/debug.log 2>&1

		psql $DBNAME -c "checkpoint" >> $OUTDIR/debug.log 2>&1

		psql $DBNAME -c "\d+" >> $OUTDIR/sizes.$s.$i.log 2>&1
		psql $DBNAME -c "\di+" >> $OUTDIR/sizes.$s.$i.log 2>&1

		for r in $(seq 1 $RUNS); do

			for m in simple prepared; do

				for c in $CLIENTS; do

	        	                pgbench -n -M $m -T $DURATION -c $c -j $c -S $DBNAME > $OUTDIR/pgbench.log 2>&1

        	                        lat_avg=$(grep 'latency average' $OUTDIR/pgbench.log | awk '{print $4}')
                	                lat_std=$(grep 'latency stddev' $OUTDIR/pgbench.log | awk '{print $4}')
	                	        tps=$(grep tps $OUTDIR/pgbench.log | tail -n 1 | awk '{print $3}')

		                        echo pgbench $MACHINE $BUILD $s $p $m $c $r $tps $lat_avg $lat_stddev

				done

			done

                done

        done

done
