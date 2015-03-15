if [ -n "$INFO" ]
then
	echo "Tag an image"
	exit 0
fi
set -u
set -e

help() {
	echo "usage: tag [-h] <image> <tag>"
}

## Main

. "$LIB/lib.sh"
load_configs
check_zfs_dirs

if [ $# -gt 0 ] && [ "$1" = '-h' ]
then
	help
	exit 0
fi
if [ $# -ne 2 ]
then
	help
	exit 1
fi
image="$1"
tag="$2"


imageid=`get_image "$image"`
if [ -z "$imageid" ]
then
	echo "Error: Image '$image' not found!" >&2
	exit 1
fi

tag_image "$imageid" "$tag"

