if [ -n "$INFO" ]
then
	echo "Stop a created container"
	exit 0
fi
set -u
set -e

help() {
	echo "usage: stop [-h] <container>"
}

## Main

. "$LIB/lib.sh"
load_configs
check_zfs_dirs

check_getopts_help $@

if [ $# -ne 1 ]
then
	echo "Error: Provide container name!" >&2
	help
	exit 1
fi
jail="$1"

jails_dir=`get_zfs_path "$ZFS_FS/jails"`
exec jail -f "$jails_dir/run/$jail.conf" -r "$jail"
