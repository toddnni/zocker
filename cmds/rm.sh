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

	zfs destroy "$ZFS_FS/jails/$jail"/z
	zfs destroy "$ZFS_FS/jails/$jail"
	rm -f "$jails_dir/run/$jail".*
done

