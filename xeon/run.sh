#!/bin/bash

set -e

MACHINE=xeon
DBNAME=test
RUNS=1
DURATION=15
#CLIENTS="1 16 32 48 64 80 96 112 128 144 160 176 192 208 224 240 256 272 288 304 320 336 352 368 384"
CLIENTS="1 2 4 8 16 32 64 96"
PARTITIONS="0 1 10 100 1000"
#BUILDS="amd64 znver3 znver4"
#BUILDS="0-master 5-fastpath 3-btscan 1-fstat 4-lock-partitions 2-mempool"
BUILDS="0-master 5-fastpath 13-master 15-master 3-btscan 1-fstat 4-lock-partitions 2-mempool"

PATH_OLD=$PATH

DATE=`date +%Y%m%d-%H%M`

for build in $BUILDS; do

	for files in 1000 32768; do

		echo `date` build: $build files: $files

		OUTDIR=$DATE/$build/$files

		mkdir -p $OUTDIR

		ulimit -a > $OUTDIR/ulimit.log

		export PATH=/var/lib/postgresql/builds/pg-$build/bin:$PATH_OLD;

		pg_config > $OUTDIR/debug.log 2>&1

		killall -9 postgres || true
		rm -Rf data

		pg_ctl -D data init > $OUTDIR/init.log 2>&1

		echo "max_connections = 1000" >> data/postgresql.conf
		echo "shared_buffers = 32GB" >> data/postgresql.conf
		echo "max_locks_per_transaction = 256" >> data/postgresql.conf
		echo "max_files_per_process = $files" >> data/postgresql.conf

		pg_ctl -D data -l $OUTDIR/pg.log start > $OUTDIR/start.log 2>&1

		./run-count.sh $MACHINE $build $OUTDIR $DBNAME $RUNS $DURATION "$CLIENTS" "$PARTITIONS" > $OUTDIR/count.csv

		./push.sh $MACHINE $OUTDIR

		./run-join.sh $MACHINE $build $OUTDIR $DBNAME $RUNS $DURATION "$CLIENTS" "$PARTITIONS" > $OUTDIR/join.csv

		./push.sh $MACHINE $OUTDIR

		./run-pgbench.sh $MACHINE $build $OUTDIR $DBNAME $RUNS $DURATION "$CLIENTS" "$PARTITIONS" > $OUTDIR/pgbench.csv

		./push.sh $MACHINE $OUTDIR

		./run-index.sh $MACHINE $build $OUTDIR $DBNAME $RUNS $DURATION "$CLIENTS" "$PARTITIONS" > $OUTDIR/pgbench.csv

		./push.sh $MACHINE $OUTDIR

		pg_ctl -D data stop > $OUTDIR/stop.log 2>&1

	done

done
