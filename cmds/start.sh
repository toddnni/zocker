if [ -n "$INFO" ]
then
	echo "Start a created container"
	exit 0
fi
set -u 
set -e

help() {
	echo "usage: start [-h] [-i] <container>"
	echo "where"
	echo " -h prints help"
	echo " -i run in interactive mode"
}

## Main

. "$LIB/lib.sh"
load_configs
check_zfs_dirs

interactive=

while getopts ih arg
do
	case "$arg" in
		i)
			interactive=1
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

if [ $# -ne 1 ]
then
	echo "Error: Provide container name!"
	help
	exit 1
fi
jail="$1"

jails_dir=`get_zfs_path "$ZFS_FS/jails"`
if [ -n "$interactive" ]
then
	exec sh "$LIB"/jail_wrapper.sh "$jails_dir/run" "$jail" ''
else
	exec sh "$LIB"/jail_wrapper.sh "$jails_dir/run" "$jail" 'log' < /dev/null > /dev/null &
fi
