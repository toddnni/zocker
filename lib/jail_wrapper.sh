clean() {
	jail -f "$run/$jail.conf" -r "$jail" 2>/dev/null
}

if [ $# -ne 3 ]
then
	echo "Error: Provide jail run dir, jail name and log or ''!"
	help
	exit 1
fi
run="$1"
jail="$2"
log="$3"

trap clean

if [ -n "$log" ]
then
	jail -f "$run/$jail.conf" -c "$jail" 2>&1 | while read l; do echo "`date '+%Y-%m-%dT%H-%M-%S%z'` $l"; done >> "$run/$jail.log"
	rvalue="$?" # TODO wrong
else
	jail -f "$run/$jail.conf" -c "$jail"
	rvalue="$?"
fi
echo "$rvalue" > "$run/$jail.exit"
clean
