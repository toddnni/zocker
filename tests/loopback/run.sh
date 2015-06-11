#!/bin/sh
. ../lib.sh
set -e
set -u

# This requires working image named base

echo "## Running a container and checking ipv4:"
zocker run -l local -n looptest base 'ifconfig lo0 | grep "inet 127\."'

echo "## Removing a container:"
zocker rm looptest

echo "## Running a container and checking ipv6:"
zocker run -l local -n looptest base 'ifconfig lo0 | grep "inet6 fe80:\."'

echo "## Removing a container:"
zocker rm looptest
