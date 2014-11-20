if [ -n "$INFO" ]
then
	echo "Create a container from an image"
	exit 0
fi
set -u 
set -e

help() {
	echo "usage: create <opts> <image> [<cmd>]"
	echo "where <opts> are"
	echo " -h              prints help"
	echo " -f hostname     hostname"
	echo " -n name         container name"
	echo " -e A=X          set environment variable"
	echo " -u user         set user in container context"
	echo " -v /host-dir:/jail-dir:r[wo] mount volume"
	echo " -l [host|none]  networking (def. host)"
}

create_scratch() {
	local imageid image_dir
	imageid=`uuidgen`
	zfs create "$ZFS_FS/images/$imageid"
	zfs create "$ZFS_FS/images/$imageid"/z
	zfs snapshot "$ZFS_FS/images/$imageid"/z@clean
	image_dir=`get_zfs_path "$ZFS_FS/images/$imageid"`
	echo "$imageid" > "$image_dir"/imageid
	freeze_image "$imageid"
	tag_image "$imageid" 'scratch'
}

# next use all argv variables

read_args_from_image_if_not_set() {
	local imageid image_dir
	imageid="$1"
	image_dir=`get_zfs_path "$ZFS_FS/images/$imageid"`
	for var in imageid parent cmd hostname name env user net volumes uuid
	do
		if eval "[ -z \"\$${var}\" ]" && [ -f "$image_dir/$var" ]
		then
			val="`cat $image_dir/$var`"
			eval "${var}='${val}'"
		fi
	done
}

set_defaults_if_not_set() {
	if [ -z "$user" ]
	then
		user='root'
	fi
	if [ -z "$net" ]
	then
		net='host'
	fi
}

save_config() {
	local jail_dir
	jail_dir=`get_zfs_path "$ZFS_FS/jails/$name"`
	for var in imageid parent cmd hostname name env user net volumes uuid
	do
		if eval "[ -n \"\$${var}\" ]"
		then
			eval "echo \$${var} > ${jail_dir}/${var}"
		fi
	done
}

generate_run_config() {
	local jails_dir
	jails_dir=`get_zfs_path "$ZFS_FS/jails"`

	echo "# Device Mountpoint FStype Options Dump Pass#" > "$jails_dir/run/$name.fstab"
	echo -n "$volumes" | awk -F : '{print $1 " " $2 " " $3}' | while read host_source jail_target rwro
	do
		echo "$host_source $jails_dir/$name/z/$jail_target nullfs $rwro 0 0" >> "$jails_dir/run/$name.fstab"
	done

	# Copy on host
	mkdir -p "$jails_dir/$name/z/etc/"
	cp -a /etc/resolv.conf /etc/localtime "$jails_dir/$name/z/etc/"

	# TODO env
	net_line="ip4=new;
ip_hostname;"
	if [ "$net" = 'none' ]
	then
		net_line="ip4=disable;"
	fi
	cp "$LIB/jail.conf" "$jails_dir/run/$name.conf"
	cat >> "$jails_dir/run/$name.conf" << EOF

'$name' {
	host.hostname='$hostname';
	host.hostuuid='$uuid';
	interface='$HOST_INTERFACE';
	$net_line
	path='$jails_dir/$name/z';
       	mount.fstab='$jails_dir/run/$name.fstab';
	exec.jail_user='$user';
        exec.start='$cmd';
}
EOF
}

## Main

. "$LIB/lib.sh"
load_configs
check_zfs_dirs

env=
parent=
user=
net=
volumes=
# These will override image settings
uuid=`uuidgen`
name=`echo "$uuid" | head -c 8 | tr '0-9' 'a-j'`
hostname="$name"

while getopts f:n:e:u:v:l:h arg
do
	case "$arg" in
		f)
			hostname="$OPTARG"
			;;
		n)
			name="$OPTARG"
			hostname="$name"
			;;
		e)
			env="$env $OPTARG"
			;;
		u)
			user="$OPTARG"
			;;
		v)
			volumes="`printf '%s%s\n' \"${volumes}\" \"${OPTARG}\"`"
			;;
		l)
			net="$OPTARG"
			;;
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

if [ $# -eq 0 ] 
then
	echo "Error: Provide image name or id!"
	help
	exit 1
fi
image="$1"

shift
cmd=
if [ $# -ge 1 ]
then
	cmd="$@"
fi

imageid=`get_image "$image"`
if [ "$image" = 'scratch' ] && [ -z "$imageid" ]
then
	create_scratch
	imageid=`get_image "$image"`
fi
if [ -z "$imageid" ]
then
	echo "Error: image '$image' not found!"
	exit 1
fi

read_args_from_image_if_not_set "$imageid"

set_defaults_if_not_set 

zfs clone "$ZFS_FS/images/$imageid"@clean "$ZFS_FS/jails/$name"
zfs clone "$ZFS_FS/images/$imageid"/z@clean "$ZFS_FS/jails/$name"/z

save_config

generate_run_config

echo "$name"
