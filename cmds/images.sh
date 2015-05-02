if [ -n "$INFO" ]
then
	echo "List images"
	exit 0
fi
set -u
set -e

help() {
	echo "usage: images [-a] [-h]"
	echo "where"
	echo " -a list also untagged intermediate images"
}

## Main

. "$LIB/lib.sh"
load_configs
check_zfs_dirs

all=

while getopts ah arg
do
	case "$arg" in
		a)
			all=1
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

images_dir=`get_zfs_path "$ZFS_FS/images"`
format="%-16s %-${UUID_LENGTH}s %-${DATE_LENGTH}s   %-13s %-${UUID_LENGTH}s\n"
printf "$format" TAG IMAGEID DATE USAGE PARENT
for imageid in `ls -t "$images_dir" | grep -v '^tags$'`
do
	tags=`find_image_tags "$imageid"`
	# Hide untagged intermediate images
	if [ -z "$all" ] && [ -z "$tags" ] && grep -q "$imageid" "$images_dir"/*/parent
	then
		continue
	fi

	if [ -z "$tags" ]
	then
		tags=-
	fi
	date=`get_zfs_date "$ZFS_FS/images/$imageid"`
	parent=-
	if [ -f "$images_dir/$imageid/parent" ]
	then
		parent="`cat $images_dir/$imageid/parent`"
	fi
	usage=`get_space_usage "$ZFS_FS/images/$imageid/z"`
	for tag in $tags
	do
		printf "$format" "$tag" "$imageid" "$date" "$usage" "$parent"
	done
done
