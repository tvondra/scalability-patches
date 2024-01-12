#!/bin/bash

set -e

MACHINE=$1
BUILD=$2
OUTDIR=$3
RUNS=$4
DURATION=$5
CLIENTS=$6
INDEXES=$7

for s in 30 300 3000; do

	for i in $INDEXES; do

		cnt=$((s*i))

		# skip cases with too many indexes
		if [[ $cnt -ge 300000 ]]; then
			continue
		fi

		DBNAME="index-$s-$p"

		cnt=$(psql -t -A -c "select count(*) from pg_database where datname = '$DBNAME'")

		if [ "$cnt" == "0" ]; then

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

			echo 'set max_parallel_maintenance_workers = 8;' >> create.sql

			# now create the indexes, spread over all the columns
			for i in `seq 1 $i`; do
				# which column to create the index on?
				c=$((i % 100 + 1))
				echo "create index on t (c$c);" >> create.sql
			done

			psql $DBNAME < create.sql > $OUTDIR/debug.log 2>&1

			psql $DBNAME -c "vacuum analyze" >> $OUTDIR/debug.log 2>&1

			psql $DBNAME -c "checkpoint" >> $OUTDIR/debug.log 2>&1

		fi

		psql $DBNAME -c "\d+" >> $OUTDIR/index.sizes.$s.$i.log 2>&1
		psql $DBNAME -c "\di+" >> $OUTDIR/index.sizes.$s.$i.log 2>&1

		# also generate the benchmark script
		echo "\set aid random(1, 100000 * $s)" > index.sql
		echo "select * from t where id = :aid;" >> index.sql

		pgbench -n -M prepared -T $((4*DURATION)) -c 32 -j 32 -f index.sql $DBNAME > $OUTDIR/index-warmup-$s-$p.log 2>&1

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
