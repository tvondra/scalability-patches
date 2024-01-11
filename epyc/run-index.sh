#!/bin/bash

set -e

MACHINE=$1
BUILD=$2
OUTDIR=$3
DBNAME=$4
RUNS=$5
DURATION=$6
CLIENTS=$7
INDEXES=$8

for s in 30 300 3000; do

	for i in $INDEXES; do

		dropdb --if-exists $DBNAME >> $OUTDIR/debug.log 2>&1
		createdb $DBNAME >> $OUTDIR/debug.log 2>&1

		# create table with a bunch of columns
		echo "CREATE TABLE t (id serial primary key" > create.sql

		# how many columns to create? 100 seems like a nice round value ;-)
		for c in `seq 1 100`; do
			echo ", c$c int"  >> create.sql
		done

		echo ");" >> create.sql

		# now also add some data
		echo 'insert into t select i' >> create.sql

		for c in `seq 1 100`; do
			echo ", i" >> create.sql
		done

		# 10k rows per scale sounds about right? pgbench has 100k, but our table is wider
		echo " from generate_series(1, $s * 10000) s(i);" >> create.sql

		echo 'vacuum analyze;' >> create.sql

		# now create the indexes, spread over all the columns
		for i in `seq 1 $i`; do
			# which column to create the index on?
			c=$((i % 100 + 1))
			echo "create index on t (c$c);" >> create.sql
		done

		psql $DBNAME < create.sql > $OUTDIR/debug.log 2>&1

		psql $DBNAME -c "vacuum analyze" >> $OUTDIR/debug.log 2>&1

		psql $DBNAME -c "checkpoint" >> $OUTDIR/debug.log 2>&1

		psql $DBNAME -c "\d+" >> $OUTDIR/sizes.$s.$i.log 2>&1
		psql $DBNAME -c "\di+" >> $OUTDIR/sizes.$s.$i.log 2>&1

		# also generate the benchmark script
		echo "\set aid random(1, 100000 * $s)" > index.sql
		echo "select * from t where id = :aid;" >> index.sql

		for r in $(seq 1 $RUNS); do

			for m in simple prepared; do

				for c in $CLIENTS; do

					pgbench -n -M $m -T $DURATION -c $c -j $c -f index.sql $DBNAME > $OUTDIR/pgbench.log 2>&1

					lat_avg=$(grep 'latency average' $OUTDIR/pgbench.log | awk '{print $4}')
					lat_std=$(grep 'latency stddev' $OUTDIR/pgbench.log | awk '{print $4}')
					tps=$(grep tps $OUTDIR/pgbench.log | tail -n 1 | awk '{print $3}')

					echo index $MACHINE $BUILD $s $i $m $c $r $tps $lat_avg $lat_stddev

				done

			done

		done

	done

done
