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
init_lib

check_getopts_help $@

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

