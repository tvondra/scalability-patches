#!/bin/bash

set -e

MACHINE=$1
BUILD=$2
OUTDIR=$3
RUNS=$4
DURATION=$5
CLIENTS=$6
PARTITIONS=$7


for p in $PARTITIONS; do

	DBNAME="count-$p"

	cnt=$(psql -t -A -c "select count(*) from pg_database where datname = '$DBNAME'")

	if [ "$cnt" == "0" ]; then

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

	fi

        echo "SELECT COUNT(*) FROM t" > select.sql

	pgbench -n -M prepared -T $((4*DURATION)) -c 32 -j 32 -f select.sql $DBNAME > $OUTDIR/count-warmup-$p.log 2>&1

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
