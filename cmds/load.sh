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
init_lib

check_getopts_help $@

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

c=0
while ! mkdir "$tmp_dir" 2>/dev/null
do
	sleep 1
	c=$((c + 1))
	if [ "$c" -gt 15 ]
	then
		echo "Error: could not lock/create '$tmp_dir' and gave up!" 2>&1
		exit 1
	fi
done

# Reads the input
tar -x -f - -C "$tmp_dir" 

if ! echo "$IMAGE_FORMAT_VERSION" | diff -q "$tmp_dir"/VERSION -
then
	echo "Error: wrong VERSION in image" >&2
	rm -r "$tmp_dir"
	exit 1
fi

imageid="`cat $tmp_dir/imageid`"
parent=
if [ -f "$tmp_dir"/parent ]
then
	parent="`cat $tmp_dir/parent`"
fi
if [ -z "$parent" ]
then
	echo "Error: parent not defined in image!" >&2
	rm -r "$tmp_dir"
	exit 1
fi
if ! [ "$parent" = "$SCRATCH_ID" ] && ! check_zfs_fs "$ZFS_FS/images/$parent"
then
	echo "Error: parent '$parent' not found from local images!" >&2
	rm -r "$tmp_dir"
	exit 1
fi

zfs create "$ZFS_FS/images/$imageid"
zfs receive "$ZFS_FS/images/$imageid"/z < "$tmp_dir"/z.send
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

