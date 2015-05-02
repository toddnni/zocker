UUID_LENGTH=36

load_configs() {
	. "$DIR/config.default"
	[ -f "$DIR/config" ] && . "$DIR/config"
}

check_zfs_fs() {
	zfs list -H "$1" > /dev/null 2>&1
}

check_zfs_dirs() {
	if ! check_zfs_fs "$ZFS_FS"
	then
		echo "Error: ZFS filesystem '$ZFS_FS' not found!" >&2
		exit 1
	fi
	check_zfs_fs "$ZFS_FS/images" || zfs create "$ZFS_FS/images"
	check_zfs_fs "$ZFS_FS/images/tags" || zfs create "$ZFS_FS/images/tags"
	check_zfs_fs "$ZFS_FS/jails" || zfs create "$ZFS_FS/jails"
	check_zfs_fs "$ZFS_FS/jails/run" || zfs create "$ZFS_FS/jails/run"
}

get_zfs_path() {
	zfs get -H -o value mountpoint "$1"
}

get_zfs_origin() {
	zfs get -H -o value origin "$1"
}

DATE_LENGTH=21
get_zfs_date() {
	zfs get -H -o value creation "$1"
}

get_image() {
	local image tags_dir
	image="$1"
	tags_dir=`get_zfs_path "$ZFS_FS/images/tags"`
	if [ -f "$tags_dir/$image" ]
	then
		image=`cat "$tags_dir/$image"`
	fi
	if check_zfs_fs "$ZFS_FS/images/$image"
	then
		echo "$image"
	fi
}

tag_image() {
	local imageid tag tag_dir
	imageid="$1"
	tag="$2"
	tags_dir=`get_zfs_path "$ZFS_FS/images/tags"`
	echo "$imageid" > "$tags_dir"/"$tag"

}

find_image_tags() {
	local imageid tag_dir
	imageid="$1"
	tags_dir=`get_zfs_path "$ZFS_FS/images/tags"`
	cd "$tags_dir"; grep -l "$imageid" * || true
}

get_space_usage() {
	local zfs_path
	zfs_path="$1"
	refer=`zfs get -H -o value referenced "$zfs_path"`
	used=`zfs get -H -o value used "$zfs_path"`
	echo "$refer ($used)"
}

freeze_image() {
	local imageid
	imageid="$1"
	zfs set readonly=on "$ZFS_FS/images/$imageid"
	zfs set readonly=on "$ZFS_FS/images/$imageid"/z
	zfs snapshot "$ZFS_FS/images/$imageid"@clean
}

clone_parent_and_receive_on_new_image() {
	local parent_path image_path
	parent_path="$1"
	image_path="$2"
	# TODO Critical, needs lock
	zfs clone "$ZFS_FS/images/$parent_path"@clean "$ZFS_FS/images/$image_path"
	zfs promote "$ZFS_FS/images/$image_path"
	zfs receive "$ZFS_FS/images/$image_path"@new 
	zfs promote "$ZFS_FS/images/$parent_path"
	zfs rename "$ZFS_FS/images/$image_path"@new "$ZFS_FS/images/$image_path"@clean 
}

test_repository_connection_or_exit() {
	if ! ssh "$REPOSITORY" ls > /dev/null
	then
		echo "Error: Could not connect to repository!" >&2
		exit 1
	fi
}
