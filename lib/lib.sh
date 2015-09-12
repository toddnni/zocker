UUID_LENGTH=36
LO_INTERFACE=lo0
IMAGE_FORMAT_VERSION=z1
SCRATCH_ID='00000000-0000-0000-0000-000000000000'

init_lib() {
	load_configs
	check_zfs_dirs
}

load_configs() {
	. "$DIR/config.default"
	if [ -f "$DIR/config" ]
	then
		. "$DIR/config"
	fi
}

check_zfs_fs() {
	zfs list -H "$1" > /dev/null 2>&1
}

ensure_zfs_fs() {
	check_zfs_fs "$1" || zfs create "$1"
}

check_zfs_dirs() {
	if ! check_zfs_fs "$ZFS_FS"
	then
		echo "Error: ZFS filesystem '$ZFS_FS' not found!" >&2
		exit 1
	fi
	ensure_zfs_fs "$ZFS_FS/images"
	ensure_zfs_fs "$ZFS_FS/images/tags"
	ensure_zfs_fs "$ZFS_FS/jails"
	ensure_zfs_fs "$ZFS_FS/jails/run"
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

check_getopts_help() {
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
	cd "$tags_dir"; grep -l "$imageid" * 2>/dev/null || true
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

test_repository_connection_or_exit() {
	if ! ssh "$REPOSITORY" ls > /dev/null
	then
		echo "Error: Could not connect to repository!" >&2
		exit 1
	fi
}

recurse_clean_unused_images() {
	local imageid parent
	imageid="$1"

	if ! ssh "$REPOSITORY" "grep -qr '$imageid' '$DIR_IN_REPO/tags' || \
		grep -qr --include='*parent' '$imageid' '$DIR_IN_REPO'"
	then
		parent=`ssh "$REPOSITORY" cat "$DIR_IN_REPO/$imageid/parent"`
		ssh "$REPOSITORY" "rm '$DIR_IN_REPO/$imageid/tar' \
			'$DIR_IN_REPO/$imageid/parent';
			rmdir '$DIR_IN_REPO/$imageid'"
		echo "Clean: Cleaned unreferenced $imageid"
		recurse_clean_unused_images "$parent"
	fi
}
