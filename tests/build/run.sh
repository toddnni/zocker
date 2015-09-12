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
zocker inspect testzfile user |grep toor
zocker inspect testzfile volumes |egrep '^/var/empty:/mnt:ro /tmp:/var/tmp:ro'

echo "## 1. Run container and check output:"
output=`zocker run -n baserun testzfile`
echo "$output" | grep 'a=2'
echo "$output" | grep 'b=3'

echo "## Check that container exists:"
zocker ps -a |grep baserun

echo "## Removing container:"
zocker rm baserun

echo "## 2. Run container and check securelevel"
zocker run -n baserun -s 3 testzfile "sysctl -n kern.securelevel |grep 3"
zocker inspect baserun securelevel |grep '3'

echo "## Removing container:"
zocker rm baserun

echo "## Removing image:"
zocker rmi testzfile
