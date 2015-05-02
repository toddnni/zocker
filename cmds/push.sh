if [ -n "$INFO" ]
then
	echo "Send a tagged image to the repository"
	exit 0
fi
set -u
set -e

help() {
	echo "usage: push [-h] <image tag>"
}

recurse_push_image() {
	local imageid parent image_dir
	imageid="$1"

	if ssh "$REPOSITORY" test -d "$DIR_IN_REPO/$imageid"
	then
		return
	fi

	image_dir=`get_zfs_path "$ZFS_FS/images/$imageid"`
	parent=-
	if [ -f "$image_dir/parent" ]
	then
		parent="`cat $image_dir/parent`"
		recurse_push_image "$parent"
	fi
	sh "$CMDS"/save.sh "$imageid" | ssh "$REPOSITORY" \
		"mkdir -p '$DIR_IN_REPO/$imageid'; \
		cat > '$DIR_IN_REPO/$imageid/tar'; \
		echo '$parent' > '$DIR_IN_REPO/$imageid/parent'"
	echo "Pushed $imageid on parent $parent"
}

tag_image_in_repo() {
	local imageid tag old_imageid
	imageid="$1"
	tag="$2"

	old_imageid=`ssh "$REPOSITORY" "[ -f '$DIR_IN_REPO/tags/$tag' ] && \
		cat '$DIR_IN_REPO/tags/$tag' || true"`

	echo "$imageid" | ssh "$REPOSITORY" "mkdir -p '$DIR_IN_REPO/tags'; \
		cat > '$DIR_IN_REPO/tags/$tag'"

	if [ -n "$old_imageid" ] && ! [ "$imageid" = "$old_imageid" ]
	then
		echo "Push: Moved tag $old_imageid -> $imageid"
		recurse_clean_unused_images "$old_imageid"
	fi
}

recurse_clean_unused_images() {
	local imageid parent
	imageid="$1"

	if ! ssh "$REPOSITORY" "grep -qr '$imageid' '$DIR_IN_REPO/tags' || \
		grep -qr --include='*parent' '$imageid' '$DIR_IN_REPO'"
	then
		parent=`ssh "$REPOSITORY" cat "$DIR_IN_REPO/$imageid/parent"`
		ssh "$REPOSITORY" "rm '$DIR_IN_REPO/$imageid/tar' \
			'$DIR_IN_REPO/$imageid/parent';
			rmdir '$DIR_IN_REPO/$imageid'"
		echo "Push: Cleaned unreferenced $imageid"
		recurse_clean_unused_images "$parent"
	fi
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

tags_dir=`get_zfs_path "$ZFS_FS/images/tags"`
if [ -f "$tags_dir/$tag" ]
then
	imageid=`cat "$tags_dir/$tag"`
else
	echo "Error: Image tag '$tag' not found!" >&2
	help
	exit 1
fi


test_repository_connection_or_exit
recurse_push_image "$imageid"
tag_image_in_repo "$imageid" "$tag"

