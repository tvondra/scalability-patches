#!/bin/bash

set -e

MACHINE=$1
BUILD=$2
OUTDIR=$3
RUNS=$4
DURATION=$5
CLIENTS=$6
PARTITIONS=$7

ps ax > $OUTDIR/star.ps.log 2>&1

for s in 1 10 100; do

	DIMROWS=$((s*100))
	ROWS=$((s*100000))

	for p in $PARTITIONS; do

		# no star joins with more than 100 dimensions
		if [[ $p -gt 100 ]]; then
			continue
		fi

		# no point in testing a case with no dimensions
		if [ "$p" == "0" ]; then
			continue
		fi

		DBNAME="star-$s-$p"

		cnt=$(psql -t -A -c "select count(*) from pg_database where datname = '$DBNAME'" postgres)

		if [ "$cnt" == "0" ]; then

			createdb $DBNAME >> $OUTDIR/debug.log 2>&1

			echo 'create table t (id serial primary key' > $OUTDIR/star-$s-$p-create.sql

			# create columns for dimension tables
			for i in $(seq 1 $p); do
				echo ", d$i int" >> $OUTDIR/star-$s-$p-create.sql
			done

			echo ');' >> $OUTDIR/star-$s-$p-create.sql

			# create dimension tables, scale * 1k rows seems reasonable
			for i in $(seq 1 $p); do
				echo "create table dim$i (id serial primary key, val int);" >> $OUTDIR/star-$s-$p-create.sql
				echo "insert into dim$i select i, i from generate_series(1,$DIMROWS) s(i);" >> $OUTDIR/star-$s-$p-create.sql
			done

			# generate insert with enough columns
			echo "insert into t select i" >> $OUTDIR/star-$s-$p-create.sql

			for i in $(seq 1 $p); do
				echo ", (1 + mod(i, $DIMROWS))" >> $OUTDIR/star-$s-$p-create.sql
			done

			echo "from generate_series(1, $ROWS) g(i);" >> $OUTDIR/star-$s-$p-create.sql

			# also create indexes on the foreign keys
			for i in $(seq 1 $p); do
				echo "create index on dim$i (id);" >> $OUTDIR/star-$s-$p-create.sql
			done

			psql $DBNAME < $OUTDIR/star-$s-$p-create.sql >> $OUTDIR/debug.log 2>&1

			psql $DBNAME -c "VACUUM FULL" >> $OUTDIR/debug.log 2>&1

			psql $DBNAME -c "VACUUM ANALYZE" >> $OUTDIR/debug.log 2>&1
			psql $DBNAME -c "CHECKPOINT" >> $OUTDIR/debug.log 2>&1

		fi

		# generate the pgbench script
		echo "\set aid random(1, $ROWS)" > $OUTDIR/star-$s-$p.sql
		echo 'select t.* from t' >> $OUTDIR/star-$s-$p.sql
		for i in $(seq 1 $p); do
			echo "join dim$i on (d$i = dim$i.id)" >> $OUTDIR/star-$s-$p.sql
		done
		echo ' where t.id = :aid' >> $OUTDIR/star-$s-$p.sql

		psql $DBNAME -c "\d+" >> $OUTDIR/star.sizes.$s.$p.log 2>&1
		psql $DBNAME -c "\di+" >> $OUTDIR/star.sizes.$s.$p.log 2>&1

		pgbench -n -M prepared -T $((4*DURATION)) -c 32 -j 32 -f $OUTDIR/star-$s-$p.sql $DBNAME > $OUTDIR/star-warmup-$s-$p.log 2>&1

		for r in $(seq 1 $RUNS); do

			for m in simple prepared; do

				for c in $CLIENTS; do

					pgbench -n -M $m -T $DURATION -c $c -j $c -f $OUTDIR/star-$s-$p.sql $DBNAME > $OUTDIR/pgbench.log 2>&1

					lat_avg=$(grep 'latency average' $OUTDIR/pgbench.log | awk '{print $4}')
					lat_stddev=$(grep 'latency stddev' $OUTDIR/pgbench.log | awk '{print $4}')
					tps=$(grep tps $OUTDIR/pgbench.log | awk '{print $3}')

					echo star $MACHINE $BUILD $s $p $m $c $r $tps $lat_avg $lag_stddev

				done

			done

		done

	done

done
