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
init_lib

check_getopts_help $@

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
if [ -z "$parent" ]
then
	echo "Error: parent not defined in image!" >&2
	exit 1
fi

mkdir -p "$tmp_dir"
echo "$IMAGE_FORMAT_VERSION" > "$tmp_dir"/VERSION
if [  "$parent" = "$SCRATCH_ID" ]
then
	zfs send "$ZFS_FS/images/$imageid/z"@clean > "$tmp_dir"/z.send
else
	zfs send -i "$ZFS_FS/images/$parent/z"@clean "$ZFS_FS/images/$imageid/z"@clean > "$tmp_dir"/z.send
fi
tar -cz -f - --exclude=z --strip-components=1 -C "$image_dir" .  -C "$tmp_dir" .
rm -r "$tmp_dir"
