#!/usr/bin/env bash

DIR=$1

for c in count join pgbench index; do

	rm -f $c.csv

	for d in $(ls $DIR); do

		for f in $(ls $DIR/$d); do

			if [ ! -f "$DIR/$d/$f/$c.csv" ]; then
				continue
			fi

			cat $DIR/$d/$f/$c.csv >> $c.csv

		done

	done

done
