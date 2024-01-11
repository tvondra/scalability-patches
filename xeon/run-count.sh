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


for p in $PARTITIONS; do

        dropdb --if-exists $DBNAME >> $OUTDIR/debug.log 2>&1
        createdb $DBNAME >> $OUTDIR/debug.log 2>&1

        if [ "$p" == "0" ]; then
                psql $DBNAME -e -c "CREATE TABLE t (a INT)" >> $OUTDIR/debug.log 2>&1
        else
            	psql $DBNAME -e -c "CREATE TABLE t (a INT) PARTITION BY HASH (a)" >> $OUTDIR/debug.log 2>&1

                for c in $(seq 1 $p); do

                        r=$((c-1))

                        psql $DBNAME -e -c "CREATE TABLE t_$r PARTITION OF t FOR VALUES WITH (modulus $p, remainder $r)" >> $OUTDIR/debug.log 2>&1

                done

        fi

	psql $DBNAME -c "INSERT INTO t SELECT i FROM generate_series(1,1000) s(i)" >> $OUTDIR/debug.log 2>&1
        psql $DBNAME -c "VACUUM ANALYZE" >> $OUTDIR/debug.log 2>&1
        psql $DBNAME -c "CHECKPOINT" >> $OUTDIR/debug.log 2>&1

        echo "SELECT COUNT(*) FROM t" > select.sql


        for r in $(seq 1 $RUNS); do

		for m in simple prepared; do

	                for c in $CLIENTS; do

        	                pgbench -n -M $m -T $DURATION -c $c -j $c -f select.sql $DBNAME > $OUTDIR/pgbench.log 2>&1

				lat_avg=$(grep 'latency average' $OUTDIR/pgbench.log | awk '{print $4}')
				lat_stddev=$(grep 'latency stddev' $OUTDIR/pgbench.log | awk '{print $4}')
	                        tps=$(grep tps $OUTDIR/pgbench.log | tail -n 1 | awk '{print $3}')

	                        echo count $MACHINE $BUILD $p $m $c $r $tps $lat_avg $lag_stddev

			done

                done

        done

done
