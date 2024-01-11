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

	        if [ "$p" == "0" ]; then
        	        pgbench -i -s $s $DBNAME >> $OUTDIR/debug.log 2>&1
	        else
        	        pgbench -i -s $s --partitions $p $DBNAME >> $OUTDIR/debug.log 2>&1
	        fi

	        psql $DBNAME -c "ALTER TABLE pgbench_accounts ADD COLUMN aid_parent INT" >> $OUTDIR/debug.log 2>&1
        	psql $DBNAME -c "UPDATE pgbench_accounts SET aid_parent = aid" >> $OUTDIR/debug.log 2>&1

	        psql $DBNAME -c "CREATE INDEX ON pgbench_accounts(aid_parent)" >> $OUTDIR/debug.log 2>&1

        	psql $DBNAME -c "VACUUM FULL" >> $OUTDIR/debug.log 2>&1

	        psql $DBNAME -c "VACUUM ANALYZE" >> $OUTDIR/debug.log 2>&1
        	psql $DBNAME -c "CHECKPOINT" >> $OUTDIR/debug.log 2>&1

		psql $DBNAME -c "\d+" >> $OUTDIR/sizes.$s.$i.log 2>&1
		psql $DBNAME -c "\di+" >> $OUTDIR/sizes.$s.$i.log 2>&1

	        for r in $(seq 1 $RUNS); do

        	        for m in simple prepared; do

                	        for c in $CLIENTS; do

                        	        pgbench -n -M $m -T $DURATION -c $c -j $c -f join.sql $DBNAME > $OUTDIR/pgbench.log 2>&1

	                                lat_avg=$(grep 'latency average' $OUTDIR/pgbench.log | awk '{print $4}')
        	                        lat_stddev=$(grep 'latency stddev' $OUTDIR/pgbench.log | awk '{print $4}')
                	                tps=$(grep tps $OUTDIR/pgbench.log | awk '{print $3}')

                        	        echo join $MACHINE $BUILD $s $p $m $c $r $tps $lat_avg $lag_stddev

				done

                        done

                done

        done

done
