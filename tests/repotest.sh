zocker=../zocker

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
	"$zocker" inspect "$1" | awk -F : '/^path/ { print $2 }'
}

echo "## Creating images (1):"

name="`$zocker create scratch`"
jail=`get_path $name`
dd if=/dev/random of="$jail/z/out1" bs=1M count=10
"$zocker" commit "$name" test10
"$zocker" rm "$name"

name="`$zocker create test10`"
jail=`get_path $name`
dd if=/dev/random of="$jail/z/out2" bs=1M count=10
"$zocker" commit "$name" test20
"$zocker" rm "$name"

test_size_10_M "`get_path test10`/z"
test_size_10_M "`get_path test20`/z"

echo "## Pushing images (1):"
"$zocker" push test10
"$zocker" push test20

echo "## Removing images (1):"
"$zocker" rmi test20
"$zocker" rmi test10

echo "## Pulling images (1):"
"$zocker" pull test10
"$zocker" pull test20

test_size_10_M "`get_path test10`/z"
test_size_10_M "`get_path test20`/z"

echo "## Removing images (1):"
"$zocker" rmi test20
"$zocker" rmi test10

echo "## Creating images (2):"

name="`$zocker create scratch`"
jail=`get_path $name`
dd if=/dev/random of="$jail/z/out1" bs=1M count=10
"$zocker" commit "$name" test10
"$zocker" rm "$name"

name="`$zocker create test10`"
jail=`get_path $name`
dd if=/dev/random of="$jail/z/out2" bs=1M count=10
"$zocker" commit "$name" test20
"$zocker" rm "$name"

test_size_10_M "`get_path test10`/z"
test_size_10_M "`get_path test20`/z"

echo "## Pushing images (2) (should replace the old ones):"
"$zocker" push test20
"$zocker" push test10

echo "## Removing images (2):"
"$zocker" rmi test20
"$zocker" rmi test10
