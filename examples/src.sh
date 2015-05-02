#!/bin/sh
set -e
set -u

zocker create -n srcbuild scratch

cd /usr/src
jail_path=`zocker inspect srcbuild | awk -F : '/^path/ {print $2}'`
make -j4 buildworld 
make installworld distribution DESTDIR="${jail_path}/z/"


zocker commit srcbuild `freebsd-version`
zocker rm srcbuild
