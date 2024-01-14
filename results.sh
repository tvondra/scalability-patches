#!/usr/bin/env bash

for test in count join pgbench index star; do

	rm -f $test.csv

	for machine in epyc i5 xeon rpi5-1 rpi5-2; do

		for run in $(ls $machine | grep 2024); do

			for build in $(ls $machine/$run); do

				for files in $(ls $machine/$run/$build); do

					if [ ! -f "$machine/$run/$build/$files/$test.csv" ]; then
						continue
					fi

					cat $machine/$run/$build/$files/$test.csv | sed "s/^/$run $files /" >> $test.csv

				done

			done

		done

	done

done
