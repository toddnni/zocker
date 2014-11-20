if [ -n "$INFO" ]
then
	echo "Show information about a container or an image"
	exit 0
fi
set -u 
set -e

help() {
	echo "usage: inspect [-h] [-i] <image>/<container>"
	echo "Matches containers first"
	echo " -i will match images only"
}

## Main

. "$LIB/lib.sh"
load_configs
check_zfs_dirs

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

if [ $# -ne 1 ]
then
	echo "Error: Provide image or container name!"
	help
	exit 1
fi
target="$1"

if [ -z "$image" ] && check_zfs_fs "$ZFS_FS/jails/$target"
then
	path=`get_zfs_path "$ZFS_FS/jails/$target"`
else
	imageid=`get_image "$target"`
	if [ -n "$imageid" ]
	then
		path=`get_zfs_path "$ZFS_FS/images/$imageid"`
	else
		echo "Error: Image or container '$target' not found!"
		exit 1
	fi
fi

echo "path:$path"
cd "$path"; find * -type f -maxdepth 0 -exec grep -H  . {} \;

