if [ -n "$INFO" ]
then
	echo "Stream to STDOUT a tar archived image"
	exit 0
fi
set -u 
set -e

help() {
	echo "usage: save [-h] <image> > file"
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
	echo "Error: Provide image name!" >&2
	help
	exit 1
fi
image="$1"

imageid=`get_image "$image"`
if [ -z "$imageid" ]
then
	echo "Error: Image '$image' not found!" >&2
	help
	exit 1
fi

run_dir=`get_zfs_path "$ZFS_FS/jails/run"`
tmp_dir="$run_dir/$imageid"
image_dir=`get_zfs_path "$ZFS_FS/images/$imageid"`
parent=
if [ -f "$image_dir/parent" ]
then
	parent="`cat $image_dir/parent`"
fi

mkdir -p "$tmp_dir"
echo "z0" > "$tmp_dir"/VERSION
if [ -n "$parent" ]
then
	# TODO Critical
	zfs rename "$ZFS_FS/images/$imageid/z"@clean "$ZFS_FS/images/$imageid/z"@imageclean
	zfs promote "$ZFS_FS/images/$imageid/z"
	zfs send -i "$ZFS_FS/images/$imageid/z"@clean "$ZFS_FS/images/$imageid/z"@imageclean > "$tmp_dir"/z.send
	zfs promote "$ZFS_FS/images/$parent/z"
	zfs rename "$ZFS_FS/images/$imageid/z"@imageclean "$ZFS_FS/images/$imageid/z"@clean
else
	zfs send "$ZFS_FS/images/$imageid/z"@clean > "$tmp_dir"/z.send
fi
tar -cz -f - --exclude=z --strip-components=1 -C "$image_dir" .  -C "$tmp_dir" .
rm -r "$tmp_dir"
