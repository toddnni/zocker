if [ -n "$INFO" ]
then
	echo "Create a container and run it from an image"
	exit 0
fi
set -u 
set -e

help() {
	echo "usage: run <opts> <image> [<cmd>]"
	echo "where <opts> are"
	echo " -h              prints help"
	echo " -f hostname     hostname"
	echo " -n name         container name"
	echo " -e A=X          set environment variable"
	echo " -u user         set user in container context"
	echo " -v /host-dir:/jail-dir:r[wo] mount volume"
	echo " -l [host|none]  networking (def. host)"
	echo " -i              run in interactive mode"
}

## Main

. "$LIB/lib.sh"
load_configs
check_zfs_dirs

createargs=
interactive=
while getopts f:n:e:u:v:l:ih arg
do
	case "$arg" in
		f|n|e|u|v|l)
			createargs="$createargs -$arg $OPTARG"
			;;
		i)
			interactive=-i
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
sh "$CMDS"/start.sh $interactive "$name"
