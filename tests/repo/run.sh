#!/bin/sh
. ../lib.sh
set -e
set -u

# This requires working repo connection

echo "## Creating images (1):"
create_10_M scratch test10
create_10_M test10 test20

test_size_10_M "`get_path test10`/z"
test_size_10_M "`get_path test20`/z"

echo "## Pushing images (1):"
zocker push test10
zocker push test20

echo "## Checking if exist (1):"
zocker search test10 | grep test10
zocker search test20 | grep test20

echo "## Removing images (1):"
zocker rmi test20
zocker rmi test10

echo "## Pulling images (1):"
zocker pull test10
zocker pull test20

test_size_10_M "`get_path test10`/z"
test_size_10_M "`get_path test20`/z"

echo "## Removing images (1):"
zocker rmi test20
zocker rmi test10

echo "## Creating images (2):"
create_10_M scratch test10
create_10_M test10 test20

test_size_10_M "`get_path test10`/z"
test_size_10_M "`get_path test20`/z"

echo "## Pushing images (2) (should replace the old ones):"
zocker push test20
zocker push test10

echo "## Checking if exist (2):"
zocker search test10 | grep test10
zocker search test20 | grep test20

echo "## Removing images (2):"
zocker rmi test20
zocker rmi test10

echo "## Removing images from repo (2):"
zocker del test20
zocker del test10
