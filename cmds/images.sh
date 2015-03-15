if [ -n "$INFO" ]
then
	echo "List images"
	exit 0
fi
set -u 
set -e

help() {
	echo "usage: images [-h]"
}

## Main

. "$LIB/lib.sh"
load_configs
check_zfs_dirs

if [ $# -eq 1 ]
then
	help
	if [ "$1" = '-h' ]
	then
		exit 0
	else
		exit 1
	fi
fi
if [ $# -ge 2 ]
then
	help
	exit 1
fi

images_dir=`get_zfs_path "$ZFS_FS/images"`
format="%-12s %-${UUID_LENGTH}s %-${DATE_LENGTH}s   %-13s %-${UUID_LENGTH}s\n"
printf "$format" TAG IMAGEID DATE USAGE PARENT
for imageid in `ls -t "$images_dir" | grep -v tags`
do
	tags=`find_image_tags "$imageid"`
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
