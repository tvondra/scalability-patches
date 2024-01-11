#!/usr/bin/env bash

MACHINE=$1
DIR=$2
DATE=$(date +%Y/%m/%d-%H:%M:%S)

git add $DIR
git commit -m "update $DATE"

while /bin/true; do

	sleep 1

	git pull -r

	if [ "$?" != "0" ]; then
		exit 1
	fi

	git push

	if [ "$?" == "0" ]; then
		break
	fi

done

exit 0
