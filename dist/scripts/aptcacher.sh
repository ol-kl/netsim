#!/bin/bash

# vim: noet sw=4 ts=4

declare BASENAME="$(readlink -f "$0")"
declare BASEDIR="$(dirname "$BASENAME")"
declare BASEDIR="$(dirname "$BASEDIR")"

[ -d /etc/apt-cacher-ng ] && exit 0

aptitude update
aptitude install apt-cacher-ng

mkdir -pm 2755 ${BASEDIR}/apt-cacher-ng
chown -R apt-cacher-ng:apt-cacher-ng ${BASEDIR}/apt-cacher-ng


# CacheDir: /var/cache/apt-cacher-ng
sed -i "s,^CacheDir:\s\+.*$,CacheDir: ${BASEDIR}/apt-cacher-ng," \
	/etc/apt-cacher-ng/acng.conf

invoke-rc.d apt-cacher-ng restart
