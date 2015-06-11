#!/bin/sh
. ../lib.sh
set -e 
set -u

# This requires working image named base

echo "## Running build:"
zocker build -t testzfile .

echo "## Checking that image exists:"
zocker images | grep testzfile

echo "## Checking files:"
path="`get_path testzfile`/z"
grep moi "$path/root/file"
grep Zockerfile "$path/root/Zockerfile"

echo "## Checking parameters:"
inspect=`zocker inspect testzfile`
echo "$inspect" |grep user:toor
echo "$inspect" |grep 'volumes:/var/empty:/mnt:ro /tmp:/var/tmp:ro'

echo "## Run container and check output:"
output=`zocker run -n baserun testzfile`
echo "$output" | grep 'a=2'
echo "$output" | grep 'b=3'

echo "## Check that container exists:"
zocker ps -a |grep baserun

echo "## Removing container:"
zocker rm baserun

echo "## Run container with new volumes and check output:"
output=`zocker run -v /var/run:/var/tmp:ro -n baserun testzfile`
inspect=`zocker inspect baserun`
echo "$inspect" |grep 'volumes:/var/empty:/mnt:ro /var/run:/var/tmp:ro'

echo "## Removing container:"
zocker rm baserun

echo "## Removing image:"
zocker rmi testzfile
