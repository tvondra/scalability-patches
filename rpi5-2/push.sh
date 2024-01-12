#!/usr/bin/env bash

MACHINE=$1
DIR=$2
DATE=$(date +%Y/%m/%d-%H:%M:%S)

git add $DIR
git commit -m "update $DATE"

for i in $(seq 1 5); do

	git pull -r || true
	git push || true

	sleep 1

done

exit 0
