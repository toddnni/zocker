if [ -n "$INFO" ]
then
	echo "Snapshot a container into an image"
	exit 0
fi
set -u
set -e

help() {
	echo "usage: commit [-h] <container> [<tag>]"
}

clone_jail_fs_to_image() {
	local jail_path image_path new_image_path tmp_dir
	jail_path="$1"
	image_path="$2"
	new_image_path="$3"
	tmp_dir=`get_zfs_path "$ZFS_FS/jails/run"`

	# TODO Critical, needs lock
	zfs snapshot "$ZFS_FS/jails/$jail_path"@new
	zfs promote "$ZFS_FS/jails/$jail_path"
	zfs send -i "$ZFS_FS/jails/$jail_path"@clean "$ZFS_FS/jails/$jail_path"@new > "$tmp_dir"/commit-stream
	zfs promote "$ZFS_FS/images/$image_path"
	clone_parent_and_receive_on_new_image "$image_path" "$new_image_path" < "$tmp_dir"/commit-stream

	zfs destroy "$ZFS_FS/jails/$jail_path"@new
	rm "$tmp_dir"/commit-stream
}

## Main

. "$LIB/lib.sh"
load_configs
check_zfs_dirs

check_getopts_help $@

if [ $# -eq 0 ] || [ $# -ge 3 ]
then
	help
	exit 1
fi
jail="$1"
tag=
if [ $# -eq 2 ]
then
	tag="$2"
fi
imageid=`uuidgen`

jail_dir=`get_zfs_path "$ZFS_FS/jails/$jail"`
old_imageid="`cat $jail_dir/imageid`"

clone_jail_fs_to_image "$jail" "$old_imageid" "$imageid"
clone_jail_fs_to_image "$jail"/z "$old_imageid"/z "$imageid"/z

image_dir=`get_zfs_path "$ZFS_FS/images/$imageid"`
# image cleanup
zfs destroy "$ZFS_FS/images/$imageid"@clean
echo "$imageid" > "$image_dir"/imageid
echo "$old_imageid" > "$image_dir"/parent

# z Cleanup
zfs destroy "$ZFS_FS/images/$imageid"/z@clean
rm -f "$image_dir/z/etc/resolv.conf" "$image_dir/z/etc/localtime"
zfs snapshot "$ZFS_FS/images/$imageid"/z@clean

# update image dir timestamp
touch "$image_dir"

freeze_image "$imageid"

if [ -n "$tag" ]
then
	tag_image "$imageid" "$tag"
fi
echo "$imageid"

