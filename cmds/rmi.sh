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

recurse_remove_unused_images() {
	local imageid images_dir jails_dir parent
	imageid="$1"
	is_first="$2"

	images_dir=`get_zfs_path "$ZFS_FS/images"`
	jails_dir=`get_zfs_path "$ZFS_FS/jails"`
	if [ "$is_first" -ne 0 ] && grep -qr "$imageid" "$images_dir/tags"
	then
		echo "Image '$imageid' has a tag, won't remove"
		return
	fi

	if grep -q "$imageid" "$images_dir"/*/parent
	then
		echo "Image '$imageid' has children images, won't remove"
		return
	fi
	if [ `ls -t "$jails_dir" | grep -v run | wc -l` -ne 0 ] && \
		grep -q "$imageid" "$jails_dir"/*/imageid
	then
		echo "Image '$imageid' has children containers, won't remove"
		return
	fi

	parent=`cat "$images_dir/$imageid/parent"`
	remove_image "$imageid"
	echo "Removed image '$imageid'"
	recurse_remove_unused_images "$parent" 1
}

remove_image() {
	local imageid tags_dir
	imageid="$1"

	zfs destroy "$ZFS_FS/images/$imageid"/z@clean
	zfs destroy "$ZFS_FS/images/$imageid"/z
	zfs destroy "$ZFS_FS/images/$imageid"@clean
	zfs destroy "$ZFS_FS/images/$imageid"

	tags_dir=`get_zfs_path "$ZFS_FS/images/tags"`
	for tags in `find_image_tags "$imageid"`
	do
		rm "$tags_dir/$tags"
	done
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

while [ $# -gt 0 ]
do
	image="$1"
	shift

	imageid=`get_image "$image"`
	if [ -z "$imageid" ]
	then
		echo "Error: Image '$image' not found!" >&2
		exit 1
	fi

	recurse_remove_unused_images "$imageid" 0

done
