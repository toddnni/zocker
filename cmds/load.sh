if [ -n "$INFO" ]
then
	echo "Load a tar archived image from STDIN"
	exit 0
fi
set -u 
set -e

help() {
	echo "usage: load [-h] [<tag>] < file"
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

if [ $# -ge 2 ]
then
	help
	exit 1
fi

run_dir=`get_zfs_path "$ZFS_FS/jails/run"`
tag=
tmp_dir="$run_dir/upload"
if [ $# -eq 1 ]
then
	tag="$1"
	tmp_dir="$run_dir/$tag"
fi

mkdir -p "$tmp_dir"
# Reads the input
tar -x -f - -C "$tmp_dir" 

if ! echo "z0" | diff -q "$tmp_dir"/VERSION -
then
	echo "Error: wrong VERSION in image"
	rm -r "$tmp_dir"
	exit 1
fi

imageid="`cat $tmp_dir/imageid`"
parent=
if [ -f "$tmp_dir"/parent ]
then
	parent="`cat $tmp_dir/parent`"
fi
if [ -n "$parent" ] && check_zfs_fs "$ZFS_FS/images/$parent"
then
	zfs create "$ZFS_FS/images/$imageid"
 	clone_parent_and_receive_on_new_image "$parent"/z "$imageid"/z < "$tmp_dir"/z.send
else
	zfs create "$ZFS_FS/images/$imageid"
	zfs receive "$ZFS_FS/images/$imageid/z"@clean < "$tmp_dir"/z.send
fi

image_dir=`get_zfs_path "$ZFS_FS/images/$imageid"`
rm "$tmp_dir"/z.send
rm "$tmp_dir"/VERSION
cp -a "$tmp_dir"/* "$image_dir"
rm -r "$tmp_dir"

freeze_image "$imageid"

if [ -n "$tag" ]
then
	tag_image "$imageid" "$tag"
fi

