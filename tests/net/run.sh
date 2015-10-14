#!/bin/sh
. ../lib.sh
set -e
set -u

# This requires working image named base and dns name test

echo "## Running a container and checking ipv4 connection:"
zocker run -l inet -f test -n inettest base 'fetch -o /dev/null http://www.google.com'

echo "## Removing the container:"
zocker rm inettest

echo "## Running a container without ipv6 and checking ipv4 connection:"
zocker run -l inet4 -f test -n inettest base  'fetch -o /dev/null http://www.google.com'

echo "## Removing the container:"
zocker rm inettest

