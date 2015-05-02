if [ -n "$INFO" ]
then
	echo "Receive a tagged image from the repository"
	exit 0
fi
set -u
set -e

help() {
	echo "usage: pull [-h] <image tag>"
}

recurse_pull_parent() {
	local imageid parent
	imageid="$1"

	if check_zfs_fs "$ZFS_FS/images/$imageid"
	then
		return
	fi

	parent=`ssh "$REPOSITORY" cat "$DIR_IN_REPO/$imageid/parent"`
	if ! [ "$parent" = '-' ]
	then
		recurse_pull_parent "$parent"
	fi
	ssh "$REPOSITORY" cat "$DIR_IN_REPO/$imageid/tar" | sh "$CMDS"/load.sh
	echo "Pulled $imageid on parent $parent"
}

## Main

. "$LIB/lib.sh"
load_configs
check_zfs_dirs

while getopts h arg
do
	case "$arg" in
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
	echo "Error: Provide tag!" >&2
	help
	exit 1
fi
tag="$1"

test_repository_connection_or_exit

imageid=`ssh "$REPOSITORY" cat "$DIR_IN_REPO/tags/$tag"`
recurse_pull_parent "$imageid"
tag_image "$imageid" "$tag"
