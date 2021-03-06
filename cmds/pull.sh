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
	if ! [ "$parent" = "$SCRATCH_ID" ]
	then
		recurse_pull_parent "$parent"
	fi
	ssh "$REPOSITORY" cat "$DIR_IN_REPO/$imageid/tar" | sh "$CMDS"/load.sh
	echo "Pulled $imageid on parent $parent"
}

## Main

. "$LIB/lib.sh"
init_lib

check_getopts_help $@

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
