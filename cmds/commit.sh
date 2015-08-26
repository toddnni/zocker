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
	local jail imageid new_imageid path jail_dir
	jail="$1"
	imageid="$2"
	new_imageid="$3"
	path="$4"
	jail_dir=`get_zfs_path "$ZFS_FS/jails/$jail"`

	zfs snapshot "$ZFS_FS/jails/${jail}$path"@new
	if [ -f "$jail_dir/parent" ]
	then
		zfs send -i "$ZFS_FS/images/${imageid}$path"@clean "$ZFS_FS/jails/${jail}$path"@new | zfs receive "$ZFS_FS/images/${new_imageid}$path"
	else
		zfs send "$ZFS_FS/jails/${jail}$path"@new | zfs receive "$ZFS_FS/images/${new_imageid}$path"
	fi
	zfs destroy "$ZFS_FS/jails/${jail}$path"@new
}

## Main

. "$LIB/lib.sh"
init_lib

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

clone_jail_fs_to_image "$jail" "$old_imageid" "$imageid" ''
clone_jail_fs_to_image "$jail" "$old_imageid" "$imageid" '/z'

image_dir=`get_zfs_path "$ZFS_FS/images/$imageid"`
# image cleanup
zfs destroy "$ZFS_FS/images/$imageid"@new
echo "$imageid" > "$image_dir"/imageid
echo "$old_imageid" > "$image_dir"/parent
# z Cleanup
zfs destroy "$ZFS_FS/images/$imageid"/z@new
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

