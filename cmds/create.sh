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
	echo " -f hostname     hostname, defaults to name"
	echo " -n name         container name"
	echo " -e A=X          set environment variable"
	echo " -u user         set user in container context"
	echo " -v /host-dir:/jail-dir:r[wo] mount from host"
	echo " -v /jail-dir[:ro]            create a volume"
	echo " -V container    mount volumes from a container"
	echo " -l [inet|local|none] networking (def. inet)"
	echo " -s securelevel  set securelevel (<1 will allow chflags)"
}

check_last_lo_address() {
	local jails_dir address anumber
	jails_dir=`get_zfs_path "$ZFS_FS/jails"`
	if [ -f "$jails_dir/run/last_lo_address" ]
	then
		return
	else
		address="$FIRST_LO_ADDRESS"
		anumber=`echo "$address" | awk -F . '{print $1 * 256*256*256 + $2 * 256*256 + $3 * 256 + $4 }'`
		echo "$anumber" > "$jails_dir/run/last_lo_address"
	fi
}

generate_lo_4address() {
	local last_anumber address anumber rnum

	last_anumber=`cat "$jails_dir/run/last_lo_address"`
	anumber="$(( $last_anumber + 1 ))"
	if [ "$(( $anumber / 256 / 256 / 256 ))" -ne 127 ]
	then
		echo "Error: Container creation interrupted, run out of local addresses!" >&2
		exit 1
	fi

	rnum="$anumber"
	address="$(( $anumber / 256 / 256 / 256 ))"

	rnum="$(( $rnum % (256 * 256 * 256) ))"
	address="${address}.$(( $rnum / 256 / 256 ))"

	rnum="$(( $rnum % (256 * 256) ))"
	address="${address}.$(( $rnum / 256 ))"

	rnum="$(( $rnum % 256 ))"
	address="${address}.$(( $rnum ))"

	echo "$anumber" > "$jails_dir/run/last_lo_address"
	echo "$address"
}

generate_lo_6address() {
	local last_anumber address anumber rnum

	interface_scope_id=`ifconfig "$LO_INTERFACE" | awk '/inet6 fe80::1%/ {print $6}' | sed 's|0x|ibase=16; |' | bc `
	last_anumber=`cat "$jails_dir/run/last_lo_address"`
	anumber="$(( $last_anumber + 1 ))"
	if [ "$(( $anumber / 256 / 256 / 256 ))" -ne 127 ]
	then
		echo "Error: Container creation interrupted, run out of local addresses!" >&2
		exit 1
	fi

	# We check the previous as we support only numbers that fits in 127.0.0.0/8
	rnum="$(( anumber - 127 * 256 * 256 * 256 ))"
	address="fe80:$interface_scope_id"
	address="${address}::`echo \"obase=16; $(( $rnum / 256 / 256 ))\" | bc`"

	rnum="$(( $rnum % (256 * 256) ))"
	address="${address}:`echo \"obase=16; $rnum\" | bc`"

	echo "$anumber" > "$jails_dir/run/last_lo_address"
	echo "$address"
}

check_volume_list_syntax() {
	# Lines are in form from:to:mode
	awk -F : -v RS=' ' '{from=$1; to=$2; mode=$3;'"
		"'if(from == "" || to == "" || mode == "" || NF != 3)'"
			"'{print "Error: volume \""$0"\" not in form from:to:mode internally"; exit 1 }'"
		"'}'
}

expand_volumes_without_source() {
	local volume from to mode volumes_dir
	volumes_dir=`get_zfs_path "$ZFS_FS/volumes"`
	awk -v RS=' ' -F : '{'"
		"'if(NF==3) { from=$1; to=$2; mode=$3; };'"
		"'if(NF==2) { from="NEWDIR_"$1; to=$1; mode=$2; };'"
		"'if(NF==1) { from="NEWDIR_"$1; to=$1; mode="rw"; };'"
		"'printf "%s:%s:%s\n",from,to,mode'"
	"'}' | while read volume
	do
		from="${volume%%:*}"
		to="${from#NEWDIR_}"
		if [ "$from" = "$to" ]
		then
			echo -n "$volume "
		else
			mode="${volume##*:}"
			from="$volumes_dir/`uuidgen`"
			echo -n "$from:$to:$mode "
		fi
	done
}

merge_volumes_in_volume_list() {
	# This uses helper id to prioritize the last volume definitions in the list
	# Lines are in form from:to:mode
	awk -F : -v RS=' ' '{from=$1; to=$2; mode=$3; helper+=1; print to, helper, from, mode}'| sort |\
		awk 'function pr() { printf "%s:%s:%s ", p_from, p_to, p_mode };'"
		"'{ if(p_to != $1 && p_to != "") { pr() }; p_to=$1; p_helper=$2; p_from=$3; p_mode=$4 };'"
		"'END { pr() }'
}

create_from_scratch() {
	local name
	zfs create "$ZFS_FS/jails/$name"
	zfs create "$ZFS_FS/jails/$name"/z
}


# next use all argv variables

read_and_merge_vars_from_images() {
	local imageid image_dir
	imageid="$1"
	image_dir=`get_zfs_path "$ZFS_FS/images/$imageid"`
	for var in imageid parent cmd hostname name user net uuid securelevel
	do
		if eval "[ -z \"\$${var}\" ]" && [ -f "$image_dir/$var" ]
		then
			val="`cat $image_dir/$var`"
			eval "${var}"='${val}'
		fi
	done
	for var in env volumes
	do
		if [ -f "$image_dir/$var" ]
		then
			val="`cat $image_dir/$var`"
			if eval "[ -n \"\$${var}\" ]"
			then
				eval "${var}"='${val}\ '"\"\$${var}\""
			else
				eval "${var}"='${val}'
			fi
		fi
	done
}

generate_volumes_list() {
	local jail_dir
	if [ -n "$volumesfrom" ]
	then
		jail_dir=`get_zfs_path "$ZFS_FS/jails/$volumesfrom"`
		volumes="$volumes `cat \"$jail_dir\"/volumes`"
	fi
	if [ -n "$volumes" ]
	then
		volumes="`echo -n "$volumes" | expand_volumes_without_source`"
		echo -n "$volumes" | check_volume_list_syntax >&2
		volumes="`echo -n "$volumes" | merge_volumes_in_volume_list`"
	fi
}

create_data_volumes() {
	local volume from vol_uuid volumes_dir
	volumes_dir=`get_zfs_path "$ZFS_FS/volumes"`
	if [ -z "$volumes" ]
	then
		return
	fi

	for volume in $volumes
	do
		from="${volume%%:*}"
		if [ "`dirname $from`" = "$volumes_dir" ]
		then
			vol_uuid=`basename "$from"`
			ensure_zfs_fs "$ZFS_FS/volumes/$vol_uuid"
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
		net='inet'
	fi
	if [ -z "$securelevel" ]
	then
		securelevel=0
	fi
}

save_config() {
	local jail_dir
	jail_dir=`get_zfs_path "$ZFS_FS/jails/$name"`
	for var in imageid parent cmd hostname name env user net volumes uuid securelevel
	do
		if eval "[ -n \"\$${var}\" ]"
		then
			eval "echo \$${var} > ${jail_dir}/${var}"
		fi
	done
}

generate_run_config() {
	local jails_dir net_line lo_4address lo_6address
	jails_dir=`get_zfs_path "$ZFS_FS/jails"`

	echo "# Device Mountpoint FStype Options Dump Pass#" > "$jails_dir/run/$name.fstab"
	echo -n "$volumes" | awk -v RS=' ' -F : '{print $1 " " $2 " " $3}' | while read host_source jail_target rwro
	do
		echo "$host_source $jails_dir/$name/z/$jail_target nullfs $rwro 0 0" >> "$jails_dir/run/$name.fstab"
	done

	# Copy on host
	mkdir -p "$jails_dir/$name/z/etc/"
	install /etc/resolv.conf "$jails_dir/$name/z/etc/"
	if [ -f /etc/localtime ]
	then
		install /etc/localtime "$jails_dir/$name/z/etc/"
	fi

	check_last_lo_address
	case "$net" in
		'none')
			net_line="ip4=disable;"
			;;
		'local')
			lo_4address=`generate_lo_4address`
			lo_6address=`generate_lo_6address`
			net_line="
	ip4.addr='$LO_INTERFACE|$lo_4address';
	ip6.addr='$LO_INTERFACE|$lo_6address';
	"
			;;
		'inet')
			lo_4address=`generate_lo_4address`
			lo_6address=`generate_lo_6address`
			net_line="
	ip4.addr='$LO_INTERFACE|$lo_4address';
	ip6.addr='$LO_INTERFACE|$lo_6address';
	ip4=new;
	ip_hostname;
	"
			;;
	esac

	case "$securelevel" in
		-1|0)
			chflags_line='allow.chflags = true;'
			;;
		*)
			chflags_line='allow.chflags = false;'
			;;
	esac


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
	exec.start="env `echo "$env $cmd" | sed 's|"|\\\"|g'`";
	securelevel = $securelevel;
	$chflags_line
}
EOF
}

## Main

. "$LIB/lib.sh"
init_lib

# These will override image settings
env=
parent=
user=
net=
volumes=
volumesfrom=
uuid=`uuidgen`
name=`echo "$uuid" | head -c 8 | tr '0-9' 'a-j'`
hostname=
hostname_set=
securelevel=

while getopts f:n:e:u:v:V:l:s:h arg
do
	case "$arg" in
		f)
			hostname="$OPTARG"
			hostname_set=y
			;;
		n)
			name="$OPTARG"
			;;
		e)
			env="$env $OPTARG"
			;;
		u)
			user="$OPTARG"
			;;
		v)
			volumes="`printf '%s%s ' \"${volumes}\" \"${OPTARG}\"`"
			;;
		V)
			volumesfrom="$OPTARG"
			;;
		l)
			net="$OPTARG"
			;;
		s)
			securelevel="$OPTARG"
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
	echo "Error: Provide image name or id!" >&2
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
if ! [ "$image" = 'scratch' ] && [ -z "$imageid" ]
then
	echo "Error: image '$image' not found!" >&2
	exit 1
fi

if [ -z "$hostname_set" ]
then
	hostname="$name"
fi

if [ "$image" = 'scratch' ]
then
	imageid="$SCRATCH_ID"
else
	read_and_merge_vars_from_images "$imageid"
fi

set_defaults_if_not_set

generate_volumes_list

# Sanitize name
name=`echo "$name" | tr './' '__'`
# Change host -> inet for backward compatibility
if [ "$net" = 'host' ]
then
	net='inet'
fi

if [ "$image" = 'scratch' ]
then
	create_from_scratch "$name"
else
	zfs clone "$ZFS_FS/images/$imageid"@clean "$ZFS_FS/jails/$name"
	zfs clone "$ZFS_FS/images/$imageid"/z@clean "$ZFS_FS/jails/$name"/z
fi

create_data_volumes

save_config

generate_run_config

echo "$name"
