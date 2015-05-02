#!/bin/sh
set -e 
set -u

for dir in */
do
	echo "#### Running $dir"
	(cd $dir; sh run.sh)
done
echo "#### ALL OK"
