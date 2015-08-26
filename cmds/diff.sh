if [ -n "$INFO" ]
then
	echo "Show changes in a container"
	exit 0
fi
set -u
set -e

help() {
	echo "usage: diff [-h] <container>"
}

## Main

. "$LIB/lib.sh"
init_lib

check_getopts_help $@

if [ $# -ne 1 ]
then
	help
	exit 1
fi
jail="$1"
jail_dir=`get_zfs_path "$ZFS_FS/jails/$jail"`
imageid="`cat $jail_dir/imageid`"

zfs diff "$ZFS_FS/images/$imageid/z"@clean "$ZFS_FS/jails/$jail"/z
