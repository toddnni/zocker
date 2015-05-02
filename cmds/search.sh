if [ -n "$INFO" ]
then
	echo "Search images from the repository"
	exit 0
fi
set -u
set -e

help() {
	echo "usage: search [-h] [<tag>]"
}

## Main

. "$LIB/lib.sh"
load_configs

check_getopts_help $@

search=
if [ $# -ge 1 ]
then
	search="$1"
fi

test_repository_connection_or_exit

ssh "$REPOSITORY" "cd '$DIR_IN_REPO/tags'; find * -name '*$search*' -exec grep -H . {} \; | tr ':' ' '"
