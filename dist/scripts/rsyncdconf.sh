#!/bin/bash

# vim: noet sw=4 ts=4

export LANG=C
export LC_ALL=C
umask 22

declare NL='
'

notice() {
	echo "${@:-EMPTY_NOTICE}" >&2
}

qwe() { 
	notice "${@:-ERROR}"
	exit 1
}

declare BASENAME="$(readlink -f "$0")"
declare BASEDIR="$(dirname "$BASENAME")"
declare BASEDIR="$(dirname "$BASEDIR")"

[ -e "${BASEDIR}/NETINTUM" -o -L "${BASEDIR}/NETINTUM" ] || mkdir -p "${BASEDIR}/NETINTUM"
NETINTUMDIR="$(readlink -f "${BASEDIR}/NETINTUM")"
[ -d "$NETINTUMDIR" ] || qwe "Error: no directory: ${BASEDIR}/NETINTUM"

[ -e /etc/rsyncd.conf ] || : >/etc/rsyncd.conf
[ -f /etc/rsyncd.conf ] || qwe "Error: no regular file: /etc/rsyncd.conf"

egrep -q '^\s*RSYNC_ENABLE=true' /etc/default/rsync || \
	sed -r -i 's/^\s*RSYNC_ENABLE=.*$/RSYNC_ENABLE=true/' /etc/default/rsync

cat <<-EOF >/etc/rsyncd.tmp
uid = root
gid = root
use chroot = yes
read only = yes
timeout = 300
EOF

oIFS="$IFS"
IFS="$NL"
declare -a RSYNCMODULES=( $(find "$NETINTUMDIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;) )
IFS="$oIFS"

for m in "${RSYNCMODULES[@]}"; do
	echo
	echo "[$m]"
	echo "path = ${NETINTUMDIR}/${m}"
done >>/etc/rsyncd.tmp

if cmp /etc/rsyncd.tmp /etc/rsyncd.conf; then
	rm /etc/rsyncd.tmp
	exit 0
fi

mv /etc/rsyncd.tmp /etc/rsyncd.conf
invoke-rc.d rsync restart
