#!/bin/bash

# vim: noet sw=4 ts=4

set -x

declare DEBMIRROR="http://cdn.debian.net/debian"

declare BASENAME="$(readlink -f "$0")"
declare BASEDIR="$(dirname "$BASENAME")"
        BASEDIR="$(dirname "$BASEDIR")" #back to parent dir
declare OUTDIR="${BASEDIR}/basefiles"


mkdir -p "$OUTDIR" && pushd "$OUTDIR" || exit 1
	case "$1" in
		sid|unstable) SUITE="sid" ;;
		wheezy|testing) SUITE="wheezy" ;;
		*) SUITE="squeeze" ;;
	esac
	for ARCH in i386 amd64; do
		if [ -e "${ARCH^^*}.tar.gz" ]; then
			if ! [ -h "${ARCH^^*}.tar.gz" ]; then
				echo "ERROR: ${ARCH^^*}.tar.gz exists but is not a link" >&2
				exit 1
			fi
		fi
		ln -sf "${ARCH}_${SUITE}.tar.gz" "${ARCH^^*}.tar.gz"
	done

	for ARCH in i386 amd64; do

		[ -e ./"${ARCH}_${SUITE}.tar.gz" ] && continue 
		# if dir with base fs exists in ./basefile, then skip the step
		if ! [ -e "${ARCH}_${SUITE}" -o -h "${ARCH}_${SUITE}" ]; then
			debootstrap --arch "$ARCH" --exclude=info,tasksel,tasksel-data "$SUITE" \
			"${ARCH}_${SUITE}" "$DEBMIRROR"
		fi
		[ -d "${ARCH}_${SUITE}" ] || continue # if dir wasn't created - abandon the current iteration and move on, i.e. basefile.tgz is not created
		pushd "${ARCH}_${SUITE}" # jumping into folder
			echo "We are in $(pwd); creating tar.gz archive ${ARCH}_${SUITE}"
				rm var/cache/apt/archives/*.deb
				rm -f ../"${ARCH}_${SUITE}.tar.gz" # removing old tgz archive, if any
				tar zcf ../"${ARCH}_${SUITE}.tar.gz" './' # creating new one
			popd
	done
popd
