if [ -n "$INFO" ]
then
	echo "Delete a tag from the repository"
	exit 0
fi
set -u
set -e

help() {
	echo "usage: del [-h] <image tag>"
}

delete_tag_in_repo() {
	local imageid tag
	tag="$1"

	imageid=`ssh "$REPOSITORY" "[ -f '$DIR_IN_REPO/tags/$tag' ] && \
		cat '$DIR_IN_REPO/tags/$tag' || true"`

	ssh "$REPOSITORY" "rm '$DIR_IN_REPO/tags/$tag'"
	echo "Del: Deleted tag $tag"
	recurse_clean_unused_images "$imageid"
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
delete_tag_in_repo "$tag"
