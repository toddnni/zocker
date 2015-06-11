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

force_umount() {
	echo "Umount '$1' failed, let's wait a second and umount it forcefully.."
	sleep 2
	zfs umount -f "$1"
}

## Main

. "$LIB/lib.sh"
load_configs
check_zfs_dirs

check_getopts_help $@

if [ $# -eq 0 ]
then
	help
	exit 1
fi

jails_dir=`get_zfs_path "$ZFS_FS/jails"`
while [ $# -gt 0 ]
do
	jail="$1"
	shift

	if jls -j "$jail" >/dev/null 2>&1
	then
		echo "Error: Container '$jail' is still running!" >&2
		exit 1
	fi
	imageid="`cat $jails_dir/$jail/imageid`"

	# Destroy will fail if umount fails, let's do it first
	zfs umount "$ZFS_FS/jails/$jail"/z || force_umount "$ZFS_FS/jails/$jail"/z
	zfs umount "$ZFS_FS/jails/$jail" || force_umount "$ZFS_FS/jails/$jail"
	zfs destroy "$ZFS_FS/jails/$jail"/z
	zfs destroy "$ZFS_FS/jails/$jail"
	rm -f "$jails_dir/run/$jail".*
done
