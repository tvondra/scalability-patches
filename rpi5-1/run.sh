#!/bin/bash

set -e

MACHINE=rpi5-1
DBNAME=test
RUNS=1
DURATION=15
CLIENTS="1 2 4 8"
PARTITIONS="0 1 10 100 1000"
BUILDS="3-btscan 1-fstat 4-lock-partitions 2-mempool"

PATH_OLD=$PATH

DATE=`date +%Y%m%d-%H%M`

export PATH=/home/debian/builds/pg-0-master/bin:$PATH_OLD;

killall -9 postgres || true

if [ ! -d "data" ]; then
	pg_ctl -D data init > init.log 2>&1

	echo "max_connections = 1000" >> data/postgresql.conf
	echo "shared_buffers = 1GB" >> data/postgresql.conf
	echo "max_locks_per_transaction = 256" >> data/postgresql.conf
fi


for build in $BUILDS; do

	for files in 1000 32768; do

		echo `date` build: $build files: $files

		OUTDIR=$DATE/$build/$files

		mkdir -p $OUTDIR

		ulimit -a > $OUTDIR/ulimit.log

		export PATH=/home/debian/builds/pg-$build/bin:$PATH_OLD;

		pg_config > $OUTDIR/debug.log 2>&1

		killall -9 postgres || true

		sleep 1

		echo "max_files_per_process = $files" >> data/postgresql.conf

		pg_ctl -D data -l $OUTDIR/pg.log start > $OUTDIR/start.log 2>&1

		psql postgres -c "select * from pg_settings" > $OUTDIR/settings.log 2>&1

		./run-count.sh $MACHINE $build $OUTDIR $RUNS $DURATION "$CLIENTS" "$PARTITIONS" > $OUTDIR/count.csv

		./push.sh $MACHINE $OUTDIR

		./run-join.sh $MACHINE $build $OUTDIR $RUNS $DURATION "$CLIENTS" "$PARTITIONS" > $OUTDIR/join.csv

		./push.sh $MACHINE $OUTDIR

		./run-pgbench.sh $MACHINE $build $OUTDIR $RUNS $DURATION "$CLIENTS" "$PARTITIONS" > $OUTDIR/pgbench.csv

		./push.sh $MACHINE $OUTDIR

		./run-index.sh $MACHINE $build $OUTDIR $RUNS $DURATION "$CLIENTS" "$PARTITIONS" > $OUTDIR/index.csv

		./push.sh $MACHINE $OUTDIR

		./run-star.sh $MACHINE $build $OUTDIR $RUNS $DURATION "$CLIENTS" "$PARTITIONS" > $OUTDIR/star.csv

		./push.sh $MACHINE $OUTDIR

		pg_ctl -D data stop > $OUTDIR/stop.log 2>&1

	done

done
