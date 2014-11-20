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

echo "## Creating images:"

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

name="`$zocker create test20`"
jail=`get_path $name`
dd if=/dev/random of="$jail/z/out3" bs=1M count=10
"$zocker" commit "$name" test30
"$zocker" rm "$name"

test_size_10_M "`get_path test10`/z"
test_size_10_M "`get_path test20`/z"
test_size_10_M "`get_path test30`/z"

echo "## Saving images:"
"$zocker" save test10 > /tmp/test10.tgz
"$zocker" save test20 > /tmp/test20.tgz
"$zocker" save test30 > /tmp/test30.tgz
ls -lh /tmp/test10.tgz /tmp/test20.tgz /tmp/test30.tgz 

echo "## Removing images:"
"$zocker" rmi test30
"$zocker" rmi test20
"$zocker" rmi test10

echo "## Adding images again:"
"$zocker" load test10 < /tmp/test10.tgz
"$zocker" load test20 < /tmp/test20.tgz
"$zocker" load test30 < /tmp/test30.tgz

test_size_10_M "`get_path test10`/z"
test_size_10_M "`get_path test20`/z"
test_size_10_M "`get_path test30`/z"

echo "## Removing images:"
"$zocker" rmi test30
"$zocker" rmi test20
"$zocker" rmi test10
