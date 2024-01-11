#!/usr/bin/bash

set -e

DBNAME=$1
PARTITIONS=$2


for p in $PARTITIONS; do

        dropdb --if-exists $DBNAME >> debug.log 2>&1
        createdb $DBNAME >> debug.log 2>&1

        if [ "$p" == "0" ]; then
                psql $DBNAME -e -c "CREATE TABLE t (a INT)" >> debug.log 2>&1
        else
            	psql $DBNAME -e -c "CREATE TABLE t (a INT) PARTITION BY HASH (a)" >> debug.log 2>&1

                for c in $(seq 1 $p); do

                        r=$((c-1))

                        psql $DBNAME -e -c "CREATE TABLE t_$r PARTITION OF t FOR VALUES WITH (modulus $p, remainder $r)" >> debug.log 2>&1

                done

        fi

	psql $DBNAME -c "INSERT INTO t SELECT i FROM generate_series(1,1000) s(i)" >> debug.log 2>&1
        psql $DBNAME -c "VACUUM ANALYZE" >> debug.log 2>&1
        psql $DBNAME -c "CHECKPOINT" >> debug.log 2>&1

        echo "SELECT COUNT(*) FROM t" > select.sql

done
