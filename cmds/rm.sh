if [ -n "$INFO" ]
then
	echo "Remove a container"
	exit 0
fi
set -u
set -e

help() {
	echo "usage: rm [-h] <container> [<container> ..]"
}

## Main

. "$LIB/lib.sh"
load_configs
check_zfs_dirs

if [ $# -eq 0 ]
then
	help
	exit 1
fi
if [ "$1" = '-h' ]
then
	help
	exit 0
fi


while [ $# -gt 0 ]
do
	jail="$1"
	shift

	jails_dir=`get_zfs_path "$ZFS_FS/jails"`
	imageid="`cat $jails_dir/$jail/imageid`"

	# Destroy will fail for some reason when after heavy IO and
	# sync doesn't help, lets do it few times
	echo -n "Waiting for filesystem to destroy "
	for i in `seq 1 60`
	do
		sleep 1
		zfs destroy "$ZFS_FS/jails/$jail"/z 2>/dev/null && break || echo -n '.'
	done
	echo

	zfs destroy "$ZFS_FS/jails/$jail"
	rm -f "$jails_dir/run/$jail".*
done

