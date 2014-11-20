if [ -n "$INFO" ]
then
	echo "Prints logs of a container"
	exit 0
fi
set -u 
set -e

help() {
	echo "usage: logs [<opts>] <container>"
	echo "where <opts> in"
	echo " -h prints help"
	echo " -f follow the log outpot"
}

## Main

. "$LIB/lib.sh"
load_configs
check_zfs_dirs

follow=

while getopts hft arg
do
	case "$arg" in
		f)
			follow=-f
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
cat "$jails_dir/run/$jail.log"
exec tail -0 $follow "$jails_dir/run/$jail.log"
