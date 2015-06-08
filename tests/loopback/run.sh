#!/bin/sh
. ../lib.sh
set -e
set -u

# This requires working image named base
# and resolvable name test

echo "## Running a container and checking ipv4:"
zocker run -l host -n test base 'ifconfig lo0 | grep "inet 127\."'

echo "## Removing a container:"
zocker rm test
