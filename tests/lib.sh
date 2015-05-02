zocker() {
	../../zocker $@
}

copy_host_to_base() {
	zocker create -n base -l none scratch
	dir="`get_path base`/z"
	rsync -a /bin /sbin /lib /libexec /etc /rescue /root /usr /var "$dir"
	mkdir "$dir"/dev
	zocker commit base base
	zocker rm base
}

create_10_M() {
	from=$1
	to=$2
	name="`zocker create $from`"
	jail=`get_path $name`
	dd if=/dev/random of="$jail/z/out" bs=1M count=10
	zocker commit "$name" "$to"
	zocker rm "$name"
}

test_size_10_M() {
	local zfs_fs
	zfs_fs="$1"
	size=`zfs get -p -H -o value used "$zfs_fs"`
	ten=$(( 10 * 1024 * 1024 ))
	one=$(( 1 * 1024 * 1024 ))
	if [ $(( $ten - $size )) -gt "$one" ] || [ $(( $ten - $size )) -lt -"$one" ]
	then
		echo "ERROR: $zfs_fs is wrong size $size != $ten"
	else
		echo "OK: $zfs_fs is ok $size == $ten"
	fi
}

get_path() {
	zocker inspect "$1" | awk -F : '/^path/ { print $2 }'
}
