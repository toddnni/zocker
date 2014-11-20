if [ -n "$INFO" ]
then
	echo "Remove an image"
	exit 0
fi
set -u 
set -e

help() {
	echo "usage: rmi [-h] <image> [<image> ..]"
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
	image="$1"
	shift

	imageid=`get_image "$image"`
	if [ -z "$imageid" ]
	then
		echo "Error: Image '$image' not found!"
		exit 1
	fi

	zfs destroy "$ZFS_FS/images/$imageid"/z@clean
	zfs destroy "$ZFS_FS/images/$imageid"/z
	zfs destroy "$ZFS_FS/images/$imageid"@clean
	zfs destroy "$ZFS_FS/images/$imageid"

	tags_dir=`get_zfs_path "$ZFS_FS/images/tags"`
	for tags in `find_image_tags "$imageid"`
	do
		rm "$tags_dir/$tags"
	done
done




