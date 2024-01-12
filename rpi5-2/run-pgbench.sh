#!/bin/bash

set -e

MACHINE=$1
BUILD=$2
OUTDIR=$3
RUNS=$4
DURATION=$5
CLIENTS=$6
PARTITIONS=$7

ps ax > $OUTDIR/pgbench.ps.log 2>&1

for s in 1 5 25; do

	for p in $PARTITIONS; do

		DBNAME="pgbench-$s-$p"

		cnt=$(psql -t -A -c "select count(*) from pg_database where datname = '$DBNAME'" postgres)

		if [ "$cnt" == "0" ]; then

			createdb $DBNAME >> $OUTDIR/debug.log 2>&1

			pgbench -i -s $s --partitions=$p $DBNAME >> $OUTDIR/debug.log 2>&1

			psql $DBNAME -c "checkpoint" >> $OUTDIR/debug.log 2>&1

		fi

		pgbench -n -M prepared -T $((DURATION*4)) -c 32 -j 32 -S $DBNAME > $OUTDIR/pgbench-warmup-$s-$p.log 2>&1

		psql $DBNAME -c "\d+" >> $OUTDIR/pgbench.sizes.$s.$p.log 2>&1
		psql $DBNAME -c "\di+" >> $OUTDIR/pgbench.sizes.$s.$p.log 2>&1

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
