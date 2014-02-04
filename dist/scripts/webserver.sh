#!/bin/bash

# vim: noet sw=4 ts=4

declare WEBROOT="/var/www"

declare BASENAME="$(readlink -f "$0")"
declare BASEDIR="$(dirname "$BASENAME")"
declare BASEDIR="$(dirname "$BASEDIR")"


WEBROOT="$(readlink -f "$WEBROOT")"
if [ ! -d "$WEBROOT" ]; then
	aptitude install lighttpd
fi
if [ ! -d "$WEBROOT" ]; then
	echo "Error: no WEBROOT: $d" >&2
	exit 1
fi

[ -h "${WEBROOT}/netscript.sh" ] || ln -s "${BASEDIR}/tmp/netscript.sh" "${WEBROOT}/netscript.sh"
[ -h "${WEBROOT}/netscript-xdvt1.sh" ] || ln -s "${BASEDIR}/tmp/netscript-xdvt1.sh" "${WEBROOT}/netscript-xdvt1.sh"
[ -h "${WEBROOT}/netscript-xdvt2.sh" ] || ln -s "${BASEDIR}/tmp/netscript-xdvt2.sh" "${WEBROOT}/netscript-xdvt2.sh"
[ -h "${WEBROOT}/netscript-tuesday.sh" ] || ln -s "${BASEDIR}/tmp/netscript-tuesday.sh" "${WEBROOT}/netscript-tuesday.sh"
[ -h "${WEBROOT}/netscript-monday.sh" ] || ln -s "${BASEDIR}/tmp/netscript-monday.sh" "${WEBROOT}/netscript-monday.sh"
[ -h "${WEBROOT}/netscript-istrukta.sh" ] || ln -s "${BASEDIR}/tmp/netscript-istrukta.sh" "${WEBROOT}/netscript-istrukta.sh"

#[ -e "${WEBROOT}/xen" ] || ln -s "${BASEDIR}/XENHOST/grml_cd/boot/grml64small/xen" "${WEBROOT}/xen"
#[ -e "${WEBROOT}/xendom.iso" ] || ln -s "${BASEDIR}/XENDOM/grml_isos/grml64-small_0.0.1.iso" "${WEBROOT}/xendom.iso"
#[ -e "${WEBROOT}/xendom_ws.iso" ] || ln -s "${BASEDIR}/XENDOM_WS/grml_isos/grml64_0.0.1.iso" "${WEBROOT}/xendom_ws.iso"


for d in "${BASEDIR}"/GRML/[A-Z]*/ ; do
	d="$(readlink -f "$d")"
	b="$(basename "$d")"
	if [ ! -d "$d" ]; then
		echo "Error: no dir: $d" >&2
		continue
	fi
	if [ -d "$d"/grml_cd ]; then
		[ -e "${WEBROOT}/$b" ] || ln -s "$d"/grml_cd "${WEBROOT}/$b"
	fi
	if [ -d "$d"/grml_isos ]; then
		# grml64-small_0.0.1.iso
		# grml*.iso
		i="$(ls -1 "${d}"/grml_isos/grml*.iso | sort -r | head -1 )"
		if [ -n "$i" -a -s "$i" ]; then
			[ -e "${WEBROOT}/${b}.iso" ] || ln -s "$i" "${WEBROOT}/${b}.iso"
		fi
	fi
done
