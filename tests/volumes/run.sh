#!/bin/sh
. ../lib.sh
set -e
set -u

# This requires working image named base

echo "## 1a. Run container with a new host volumes and check output:"
zocker run -l local -v /tmp:/var/tmp:ro -n volumetest base echo running
zocker inspect volumetest volumes |egrep '^/tmp:/var/tmp:ro'
volume_path=`zocker inspect volumetest volumes | awk -F : '{print $1}'`

echo "## 1b. Creating a image from the container and check output:"
echo "## The original path is saved as in first Zocker versions"
zocker commit volumetest hostvolume
zocker inspect hostvolume volumes | egrep '^/tmp:/var/tmp:ro'

echo "## 1c. Removing container with -v and check that volume is not deleted:"
zocker rm -v volumetest
test -d "$volume_path"

echo "## 1d. Start a new container from the image with a new host volume mount:"
zocker run -l local -v /var/tmp:/var/tmp:ro -n volumetest base echo running
zocker inspect volumetest volumes |egrep '^/var/tmp:/var/tmp:ro'

echo "## Removing the container:"
zocker rm volumetest

echo "## 1e. Start a new container from the image without a host volume:"
echo "## This uses the volume full path from the image"
zocker run -l local -n volumetest hostvolume echo running
zocker inspect volumetest volumes |egrep '^/tmp:/var/tmp:ro'

echo "## Removing the container:"
zocker rm volumetest

echo "## Removing the image:"
zocker rmi hostvolume

echo "## 2a. Running a container with a new volume and checking:"
zocker run -l local -n volumetest -v /mnt base 'echo hello > /mnt/out'
zocker inspect volumetest volumes |egrep 'volumes/[0-9a-z\-]+:/mnt:rw'
volume_path=`zocker inspect volumetest volumes | awk -F : '{print $1}'`
grep hello "$volume_path/out"

echo "## 2b. Saving the image:"
echo "## Now the path is not saved"
zocker commit volumetest localvolume
zocker inspect localvolume volumes | egrep '^/mnt:rw'

echo "## 2c. Removing the container with -v and check if the volume is deleted:"
zocker rm -v volumetest
test ! -d "$volume_path"  || false
echo 'Volume is deleted.'

echo "## 3. Creating a container from the image with another ro volume:"
zocker run -l local -n volumetest -v /var/tmp:ro localvolume 'echo hellotoo > /mnt/out'
zocker inspect volumetest volumes |egrep 'volumes/[0-9a-z\-]+:/mnt:rw'
zocker inspect volumetest volumes |egrep 'volumes/[0-9a-z\-]+:/var/tmp:ro'

echo "## 4. Creating another container and mounting volumes from another container:"
zocker run -l local -n volumetest2 -V volumetest localvolume 'grep hellotoo /mnt/out'
zocker inspect volumetest2 volumes |egrep 'volumes/[0-9a-z\-]+:/mnt:rw'
zocker inspect volumetest2 volumes |egrep 'volumes/[0-9a-z\-]+:/var/tmp:ro'
volume_paths=`zocker inspect volumetest2 volumes | awk -v RS=' ' -F : '{print $1}'`
test "`zocker inspect volumetest volumes`" = "`zocker inspect volumetest2 volumes`"

echo "## 5. Commit the container and check that all the local paths are purged:"
zocker commit volumetest2 localvolume2
zocker inspect localvolume2 volumes | egrep '^/mnt:rw /var/tmp:ro'

echo "## Removing the first container:"
zocker rm volumetest

echo "## Removing the last container with -v and checking:"
zocker rm -v volumetest2
for volume_path in $volume_paths
do
	test ! -d "$volume_path"  || false
done
echo 'All the volumes deleted'

echo "## Removing the images"
zocker rmi localvolume2
zocker rmi localvolume
