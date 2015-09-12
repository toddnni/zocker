if [ -n "$INFO" ]
then
	echo "Remove a container"
	exit 0
fi
set -u
set -e

help() {
	echo "usage: rm [-v] [-h] <container> [<container> ..]"
	echo " -v will delete the zocker volumes also"
}

force_umount() {
	echo "Umount '$1' failed, let's wait a second and umount it forcefully.."
	sleep 2
	zfs umount -f "$1"
}

## Main

. "$LIB/lib.sh"
init_lib

remove_volumes=

while getopts vh arg
do
	case "$arg" in
		v)
			remove_volumes=y
			;;
		h)
			help
			exit 0
			;;

		*)
			help
			exit 1
			;;
	esac
done
shift $(( $OPTIND-1 ))

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

	# Volumes
	if [ -n "$remove_volumes" ] && [ -f "$jails_dir/$jail/volumes" ]
	then
		volumes_dir=`get_zfs_path "$ZFS_FS/volumes"`
		awk -v RS=' ' '{print $0}' "$jails_dir/$jail/volumes" | while read volume
		do
			from="${volume%%:*}"
			if [ -n "$volume" ] && [ "`dirname $from`" = "$volumes_dir" ]
			then
				vol_uuid=`basename "$from"`
				zfs umount "$ZFS_FS/volumes/$vol_uuid"
				zfs destroy "$ZFS_FS/volumes/$vol_uuid"
				echo "Destroyed volume '$vol_uuid'"
			fi
		done

	fi

	# Destroy will fail if umount fails, let's do it first
	zfs umount "$ZFS_FS/jails/$jail"/z || force_umount "$ZFS_FS/jails/$jail"/z
	zfs umount "$ZFS_FS/jails/$jail" || force_umount "$ZFS_FS/jails/$jail"
	zfs destroy "$ZFS_FS/jails/$jail"/z
	zfs destroy "$ZFS_FS/jails/$jail"
	rm -f "$jails_dir/run/$jail".*

done
