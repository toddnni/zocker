if [ -n "$INFO" ]
then
	echo "Show information about a container or an image"
	exit 0
fi
set -u
set -e

help() {
	echo "usage: inspect [-h] [-i] <image>/<container> [<parameter> ..]"
	echo "Matches containers first"
	echo " -i will match images only"
}

## Main

. "$LIB/lib.sh"
init_lib

image=

while getopts hi arg
do
	case "$arg" in
		i)
			image=1
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

if [ $# -lt 1 ]
then
	echo "Error: Provide image or container name!" >&2
	help
	exit 1
fi
target="$1"
shift

if [ -z "$image" ] && check_zfs_fs "$ZFS_FS/jails/$target"
then
	path=`get_zfs_path "$ZFS_FS/jails/$target"`
else
	imageid=`get_image "$target"`
	if [ -n "$imageid" ]
	then
		path=`get_zfs_path "$ZFS_FS/images/$imageid"`
	else
		echo "Error: Image or container '$target' not found!" >&2
		exit 1
	fi
fi

if [ $# -eq 0 ]
then
	echo "path:$path"
	cd "$path"; find * -type f -maxdepth 0 -exec grep -H  . {} \;
fi
while [ $# -gt 0 ]
do
	parameter="$1"
	if [ "$parameter" = 'path' ]
	then
		echo "$path"
	else
		cat "$path/$parameter"
	fi
	shift
done

