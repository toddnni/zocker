if [ -n "$INFO" ]
then
	echo "Build a new image from Zockerfile"
	exit 0
fi
set -u
set -e

help() {
	echo "usage: build [-h] [-t <tag>] <path>"
	echo "Zockerfile is searched under <path>"
	echo " -h        prints help"
	echo " -t tag    tags the new image"
	echo "Zockerfile supports following instructions"
	echo
	echo "  FROM <image>     (the first instruction)"
	echo "  RUN <commands>   (runs in shell and commits)"
	echo "  COPY <src> <dst> (from host to container)"
	echo "  USER <user>      (commit user information)"
	echo "  ENV <a>=<va> <b>=<vb>  (commit env)"
	echo "  CMD <cmd>        (cmd to run when container is started."
	echo "                    After the last run instruction)"
	echo "  VOLUME <volume>  (a volume or volumes to create)"
	echo
	echo " following are special to Zocker"
	echo "  NET <hostname|none>  (special to zocker. All the following"
	echo "                        instructions will use the hostname"
	echo "                        to access internet)"
}

check_base_defined() {
	local base_image
	base_image="$1"
	if [ -z "$base_image" ]
	then
		echo "Error: FROM must be the first instruction" >&2
		exit 1
	fi
}

net_params() {
	local net
	net="$1"
	if [ "$net" = 'none' ]
	then
		echo '-l none'
	else
		echo "-l inet -f '$net'"
	fi
}

check_count() {
	local count
	count="$1" # -1 means at least one
	shift

	if [ "$count" -eq -1 ]
	then
		if [ $# -eq 0 ]
		then
			echo "Error: There should be at least one parameter" >&2
			exit 1
		fi
	else
		if [ $# -ne "$count" ]
		then
			echo "Error: Parameter count doesn't match '$count'" >&2
			exit 1
		fi
	fi
}

## Main

. "$LIB/lib.sh"
init_lib

tag=

while getopts t:h arg
do
	case "$arg" in
		t)
			tag="$OPTARG"
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

if [ $# -ne 1 ] 
then
	echo "Error: Provide path (eg. .)!" >&2
	help
	exit 1
fi
cd "$1"
if ! [ -r 'Zockerfile' ]
then
	echo "Error: Could not read Zockerfile from dir '$1'" >&2
	exit 1
fi

base_image=
net=none
c_name=build

echo "## Using container '$c_name', it must be manually removed in some errors" 
while read instruction params
do
	if [ -z "$instruction" ] || ! [ "${instruction#\#}" = "$instruction" ]
	then
		continue
	fi

	echo "## $instruction $params"
	set -- $params
	commit_and_remove_build=
	case "$instruction" in
		FROM)
			check_count  1 $@
			base_image=`get_image "$1"`
			if [ -z "$base_image" ]
			then
				echo "Error: Image '$1' not found!" >&2
				exit 1
			fi
			imageid="$base_image"
			;;
		NET)
			check_base_defined "$base_image"
			check_count 1 $@
			net="$1"
			;;
		RUN)
			check_base_defined "$base_image"
			check_count -1 $@
			sh "$CMDS"/run.sh -n "$c_name" `net_params "$net"` "$imageid" sh -c "\'$@\'"
			commit_and_remove_build=1
			;;
		USER)
			check_base_defined "$base_image"
			check_count 1 $@
			sh "$CMDS"/create.sh -n "$c_name" -u "$1" "$imageid"
			commit_and_remove_build=1
			;;
		CMD)
			check_base_defined "$base_image"
			check_count -1 $@
			sh "$CMDS"/create.sh -n "$c_name" "$imageid" "$@"
			commit_and_remove_build=1
			;;
		VOLUME)
			check_base_defined "$base_image"
			check_count -1 $@
			volume_params=
			while [ $# -gt 0 ]
			do
				volume_params="$volume_params -v $1"
				shift
			done
			sh "$CMDS"/create.sh -n "$c_name" $volume_params "$imageid"
			commit_and_remove_build=1
			;;
		ENV)
			check_base_defined "$base_image"
			check_count -1 $@
			env_params=
			while [ $# -gt 0 ]
			do
				env_params="$env_params -e $1"
				shift
			done
			sh "$CMDS"/create.sh -n "$c_name" $env_params "$imageid"
			commit_and_remove_build=1
			;;
		COPY)
			check_base_defined "$base_image"
			check_count 2 $@
			sh "$CMDS"/create.sh -n "$c_name" "$imageid"
			jail_dir=`get_zfs_path "$ZFS_FS/jails/$c_name"`
			cp -a "$1" "$jail_dir/z/$2"
			chown -Rhx 0:0 "$jail_dir/z/$2"
			commit_and_remove_build=1
			;;
		*)
			echo "Error: Unknown instruction '$instruction'!" >&2
			exit 1
			;;
	esac
	if [ -n "$commit_and_remove_build" ]
	then
		imageid=`sh "$CMDS"/commit.sh "$c_name"`
		sh "$CMDS"/rm.sh -v "$c_name"
	fi
	echo "# - $imageid"

done < Zockerfile

if [ -n "$tag" ]
then
	tag_image "$imageid" "$tag"
	echo "# Tagged '$tag'"
fi
