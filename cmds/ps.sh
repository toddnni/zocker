if [ -n "$INFO" ]
then
	echo "List containers"
	exit 0
fi
set -u 
set -e

help() {
	echo "usage: ps [-a] [-h]"
	echo "where"
	echo " -a list stopped containers also"
}

## Main

. "$LIB/lib.sh"
load_configs
check_zfs_dirs

all=

while getopts ah arg
do
	case "$arg" in
		a)
			all=1
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

jails_dir=`get_zfs_path "$ZFS_FS/jails"`
for jail in `ls -t "$jails_dir" | grep -v run`
do
	imageid="`cat $jails_dir/$jail/imageid`"
	date=`get_zfs_date "$ZFS_FS/jails/$jail"`
	usage=`get_space_usage "$ZFS_FS/jails/$jail/z"`
	cmd=
	if [ -f "$jails_dir/$jail/cmd" ]
	then
		cmd="`cat $jails_dir/$jail/cmd`"
	fi
	if ip="`jls -q -j \"$jail\" ip4.addr 2>/dev/null`"
	then
		status=up
	else
		ip=-
		status=clean
		if [ -f "$jails_dir/run/$jail.exit" ]
		then
			status="exit(`cat $jails_dir/run/$jail.exit`)"
		fi
	fi
	if [ "$status" = 'up' ] || [ -n "$all" ]
	then
		printf "%-12s %s %s %-7s %-15s %-13s %-20s\n" "$jail" "$imageid" "$date" "$status" "$ip" "$usage" "'$cmd'"
	fi
done
