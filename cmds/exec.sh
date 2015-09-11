if [ -n "$INFO" ]
then
	echo "Run a command in a running container"
	exit 0
fi
set -u
set -e

help() {
	echo "usage: exec [-h] <container> <command> [<args> ..]"
	echo "where"
	echo " -h prints help"
}

## Main

. "$LIB/lib.sh"
init_lib

check_getopts_help $@

if [ $# -lt 2 ]
then
	echo "Error: Provide a container name and a command!" >&2
	help
	exit 1
fi
jail="$1"
shift

jexec "$jail" "$@"
