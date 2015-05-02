#!/bin/sh
. ../lib.sh
set -e 
set -u

echo "## Creating images:"
create_10_M scratch test10
create_10_M test10 test20
create_10_M test20 test30

test_size_10_M "`get_path test10`/z"
test_size_10_M "`get_path test20`/z"
test_size_10_M "`get_path test30`/z"

echo "## Saving images:"
zocker save test10 > /tmp/test10.tgz
zocker save test20 > /tmp/test20.tgz
zocker save test30 > /tmp/test30.tgz
ls -lh /tmp/test10.tgz /tmp/test20.tgz /tmp/test30.tgz 

echo "## Removing images:"
zocker rmi test30
zocker rmi test20
zocker rmi test10

echo "## Adding images again:"
zocker load test10 < /tmp/test10.tgz
zocker load test20 < /tmp/test20.tgz
zocker load test30 < /tmp/test30.tgz

test_size_10_M "`get_path test10`/z"
test_size_10_M "`get_path test20`/z"
test_size_10_M "`get_path test30`/z"

echo "## Removing images:"
zocker rmi test30
zocker rmi test20
zocker rmi test10
rm /tmp/test10.tgz
rm /tmp/test20.tgz
rm /tmp/test30.tgz
