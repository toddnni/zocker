if [ -n "$INFO" ]
then
	echo "Create a container and run it from an image"
	exit 0
fi
set -u
set -e

# Sync with create.sh
help() {
	echo "usage: run <opts> <image> [<cmd>]"
	echo "where <opts> are"
	echo " -h              prints help"
	echo " -f hostname     hostname, defaults to name"
	echo " -n name         container name"
	echo " -e A=X          set environment variable"
	echo " -u user         set user in container context"
	echo " -v /host-dir:/jail-dir:r[wo] mount volume"
	echo " -l [inet|local|none] networking (def. inet)"
	echo " -s securelevel  set securelevel (<1 will allow chflags)"
}

## Main

. "$LIB/lib.sh"
load_configs
check_zfs_dirs

createargs=
while getopts f:n:e:u:v:l:s:h arg
do
	case "$arg" in
		f|n|e|u|v|l|s)
			createargs="$createargs -$arg $OPTARG"
			;;
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

if [ $# -eq 0 ]
then
	help
	exit 1
fi

name=`sh "$CMDS"/create.sh $createargs $@`
exec sh "$CMDS"/start.sh "$name"
