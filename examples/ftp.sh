#!/bin/sh
set -e
set -u

FREEBSD_HOST=${FREEBSD_HOST-http://ftp.freebsd.org/pub/FreeBSD/releases/}
ARCH=${ARCH-amd64}
RELEASE=${RELEASE-10.2-RELEASE}
zocker create -n ftpbuild scratch

jail_path=`zocker inspect ftpbuild path`
for dist in base.txz lib32.txz
do
	echo "# $dist"
	fetch "$FREEBSD_HOST/$ARCH/$RELEASE/$dist"
	tar -xpf "$dist" -C "${jail_path}/z/"
	rm "$dist"
done

zocker commit ftpbuild "$RELEASE"
zocker rm ftpbuild
zocker run -n build "$RELEASE" "freebsd-update --not-running-from-cron fetch install; rm -rf /var/db/freebsd-update/files"
zocker commit build "$RELEASE"
zocker rm build
