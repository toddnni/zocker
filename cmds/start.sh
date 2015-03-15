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
}

clean() {
	jail -f "$jails_dir/run/$jail.conf" -r "$jail"
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
	echo "Error: Provide container name!" >&2
	help
	exit 1
fi
jail="$1"

jails_dir=`get_zfs_path "$ZFS_FS/jails"`
trap clean
jail -f "$jails_dir/run/$jail.conf" -c "$jail" || true
clean
