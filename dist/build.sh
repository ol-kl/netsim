#!/bin/bash
# vim: noet sw=4 ts=4
#set locales to ASCII (C)
#set -x
set -u
shopt -s extglob # enabling extended pattern matching
export LANG=C
export LC_ALL=C
umask 22 #declare files not being writable for anyone besides owner

declare NL='
'

notice() {
	echo "${@:-EMPTY_NOTICE}" >&2
}

qwe() {
	notice "${@:-ERROR}"
	exit 1
}

BASENAME="$(readlink -f "$0")"
BASEDIR="$(dirname "$BASENAME")" # name of scipt invocation directory

# Here DIST stands for a distribution package name as defined further

usage="usage: $(basename "$0") [init|<DIST>]

  dists:  SERV32 /path/to/squashfs_file_of_client
  	  SERV64 /path/to/squashfs_file_of_client
  	  PROBE32
	  PROBE64"

help="First use \"init\" argument to download configs from Mercurial, only then
invoke the command $(basename "$0") with appropriate distrib name.$NL
$usage"

LIVEOPTS='-F' # force-mode, without asking questions - non interactive

grmlflavsize=''
grmlsize=''
grmlbit=''
grmlsuite='squeeze'
nonfs=''

if (( $# > 2 )); then
	qwe 'Error: There must at most two arguments. Use -h for help.';
fi

is_init() {
	if [[ -d ${BASEDIR}/GRML && -d ${BASEDIR}/fai/config ]]; then
		return 0
	else
		return 1
	fi
}


initialize() {
	# Creates /GRML dir for results of the script, and
	# /basefiles -> ./fai/config/basefiles
	#
	# here emptiness of a GRML dir can be verified:
	# if find ${BASEDIR}/GRML -mindepth 1 | wc -l; then
	# blah blah ... (GRML dir is not empty)
	# fi
	
	BFC=${BASEDIR}/fai/config

	mkdir -p "${BASEDIR}/GRML" || qwe "Could not mkdir ${BASEDIR}/GRML"
	
	if [ -d "$BFC" ]; then
		rm -r ${BASEDIR}/fai
	else
		mkdir -p $BFC
		! [ -d $BFC ] && qwe "Directory ./fai/conf failed to be created"
		hg clone https://projects.net.in.tum.de/hg/netsim $BFC
		rm -r ${BFC}/!(dist) # removing all but 'dist' directory
		cp -r ${BFC}/dist/fai/config/* ${BFC}/ 
		rm -r ${BFC}/dist
	#	qwe "Error: ${BASEDIR}/fai/config does not exist"
	fi

	"${BASEDIR}/scripts/basefiles.sh" # populates ./basefiles dir with .tgz archives of chroot-ready base systems

	[ -e "${BASEDIR}/fai/config/basefiles" -o -L "${BASEDIR}/fai/config/basefiles" ] || \
		ln -s "${BASEDIR}/basefiles" "${BASEDIR}/fai/config/basefiles"

	"${BASEDIR}/scripts/aptcacher.sh" #configure apt-cacher-ng to add all packages in ./apt-cacher-ng dir
#	"${BASEDIR}/scripts/rsyncdconf.sh" #configure rsync
#	"${BASEDIR}/scripts/webserver.sh" #populate local webserv directory

}

#while [ -n "$1" ]; do
	case "$1" in
		SERV32)
			grmlsize=small
			grmlbit=32
			CLASSES=NETSERV
			LIVEOPTS="${LIVEOPTS}"
			nonfs='y'
			shift
			NETPROBE_IMG=$(readlink -f $1 2>/dev/null)
			;;
		SERV64)
			grmlsize=small
			grmlbit=64
			CLASSES=NETSERV
			LIVEOPTS="${LIVEOPTS}"
			nonfs='y'
			shift
			NETPROBE_IMG=$(readlink -f $1 2>/dev/null)
			;;
		PROBE32)
			grmlsize=small
			grmlbit=32
			CLASSES=NETPROBE
			LIVEOPTS="${LIVEOPTS} -n"
			nonfs='y'
			;;
		PROBE64)
			grmlsize=small
			grmlbit=64
			CLASSES=NETPROBE
			LIVEOPTS="${LIVEOPTS} -n"
			nonfs='y'
			;;

		init)
			initialize
			exit $?
			;;
		-h)
			echo -e "$help"
			exit 0
			;;
		*)
			qwe "$usage"
			;;

	esac
#[ -n "$netintumclass" ] || netintumclass="$1"
#shift -no further args processing at the moment
#done

is_init || qwe "Configuration environment is not prepared. Consider invoking script with \"init\" argument."

[ -n "$CLASSES" ] || qwe "$usage"

if [[ "$CLASSES" == NETSERV ]]; then
	[ -z "$NETPROBE_IMG" ] && \
	qwe "Distrib names SERV32 and SERV64 must be followed by a path to a squashfs image
for a client, which is to be incorporated into squashfs image of the server"
	[[ ${NETPROBE_IMG:$(expr index ${NETPROBE_IMG} '.')} != squashfs ]] && \
	qwe "Provided squashfs image doesn't have .squashfs suffix"
fi


#[ -z "$RUNMODE" -a -n "$grmlsize" ] && RUNMODE=grml

if [ -n "$nonfs" ]; then
	sed -i 's/^nfs-common/#nfs-common/' /etc/grml/fai/config/package_config/GRMLBASE
	sed -i 's/^rpcbind/#rpcbind/' /etc/grml/fai/config/package_config/GRML_SMALL
else
	sed -i 's/^#nfs-common/nfs-common/' /etc/grml/fai/config/package_config/GRMLBASE
	sed -i 's/^#rpcbind/rpcbind/' /etc/grml/fai/config/package_config/GRML_SMALL
fi

case "$grmlbit" in
	32)
		if [[ $CLASSES == NETPROBE ]]; then
			OUTDIR="${BASEDIR}/GRML/PROBE32"
		else
			OUTDIR="${BASEDIR}/GRML/SERV32"
		fi
		grmlflavbit=''
		baseclass='I386'
		;;
	64)
		if [[ $CLASSES == NETPROBE ]]; then
			OUTDIR="${BASEDIR}/GRML/PROBE64"
		else
			OUTDIR="${BASEDIR}/GRML/SERV64"
		fi
		grmlflavbit='64'
		baseclass='AMD64'
		;;
	*)
		qwe "grmlbit is set incorrectly: $grmlbit"
		;;
esac

echo "Output dir is $OUTDIR"

case "$grmlsize" in
	base)
		grmlflavsize="${grmlflavsize:-small}"
		grmlclass='GRMLBASE'
		;;
	small)
		grmlflavsize="${grmlflavsize:-small}"
		grmlclass='GRMLBASE,GRML_SMALL'
		;;
	medium)
		grmlflavsize="${grmlflavsize:-medium}"
		grmlclass='GRMLBASE,GRML_MEDIUM'
		;;
	full)
		grmlflavsize="${grmlflavsize:-full}"
		grmlclass='GRMLBASE,GRML_FULL'
		;;
	*)
		qwe "Error: invalid grmlsize: $grmlsize"
		;;
esac

grmlflavsize="-${grmlflavsize}"

[[ "$grmlflavsize" == '-full' ]] && grmlflavsize=''
	
echo 'Copying ./grml-live.conf into /etc/grml/ as grml-live.local'	
echo

[[ -r "${BASEDIR}/grml-live.conf" ]] && cp "${BASEDIR}/grml-live.conf" /etc/grml/grml-live.local

echo 'Copying ./fai/config directory into /etc/grml/fai/config'
echo

# Remove the following option -i, it's only for debugging
cp -a "${BASEDIR}/fai/config" -T /etc/grml/fai/config # copying all conf files to grml fai directory, where they will be read by grml-live

# Creating file class/NETSSERV.var to let scripts know where to get squashfs image of client
if [[ "$CLASSES" == NETSERV ]]; then
	if [ -e "${BASEDIR}/fai/config/class/NETSERV.var" ]; then
		rm "${BASEDIR}/fai/class/NETSERV.var" 
		echo "File class/NETSERV.var existed before, as a result it was recreated"
	fi
	echo "Creating class/NETSERV.var"
	cat << 'EOF' > ${BASEDIR}/fai/config/class/NETSERV.var
#This file was automaticly created during run of build.sh
#Attempts to change it are useless, as during the next build it will be overwritten
EOF
	echo "NETPROBE_IMG=${NETPROBE_IMG}" >> "${BASEDIR}/fai/config/class/NETSERV.var"
fi

echo "Fixing GRMLBASE/45-grub-images file"
echo

sed -i '8s/^\s*$/exit 0/' /etc/grml/fai/config/scripts/GRMLBASE/45-grub-images #inserting 'exit 0' in the very begining of the file after info block

echo "Removing grub related packages from install list in GRMLBASE (due to bug issues)"
echo 
sed -i 's/^grub/#&/g' /etc/grml/fai/config/package_config/GRMLBASE 

if < /etc/grml/fai/config/scripts/GRML_SMALL/98-clean-chroot | grep 'remove aptitude' > /dev/null; then # sanity check: new versions of grml-live don't have this problem
	echo "Fixing GRML_SMALL/98-clean-chroot file to prevent aptitude removing"
	sed -i -r 's/^(\$ROOTCMD apt-get -y --purge remove aptitude)\s*$/#\1/' /etc/grml/fai/config/scripts/GRML_SMALL/98-clean-chroot #comment the line to avoid removing of aptitude
fi

[[ -e /etc/grml/fai/config/basefiles ]] || ln -s "${BASEDIR}/basefiles" /etc/grml/fai/config/basefiles
	
grmlflavour="grml${grmlflavbit}${grmlflavsize}"
echo "grml flavour is set to $grmlflavour"

if [[ -d "$OUTDIR" ]]; then
	echo "Directory $OUTDIR exists, therefore softupdate will be used"
	LIVEOPTS="${LIVEOPTS} -u" # employing soft-update feature of FAI
fi
	
# "${BASEDIR}/scripts/basefiles.sh" "$grmlsuite"
echo "Launching grml-live..."
echo

grml-live $LIVEOPTS -g "$grmlflavour" -o "$OUTDIR" -s "$grmlsuite" \
	-c "NETSIM_DEFAULT${grmlclass}${grmlclass:+,}${CLASSES}${CLASSES:+,}${baseclass}" -V || exit 1 # will look like: -c GRMLBASE,GRML_SMALL,NETSERV,AMD64 (it's example!)

# !!!! if packages downloading fails, one need to stop grml-live before compressing chroot to add missed directories for 
# correct work of aptitude, only then run remaining stages using grml-live -u option. Option -N is used to stop grml-live.

chmod 644 "${OUTDIR}/grml_cd/boot/grml"*/initrd.gz || \
	chmod 644 "${OUTDIR}/grml_cd/boot/grml"*/initrd.img

if [[ -n "$XENCOPY"  ]]; then
		notice "BEGIN XENCOPY"
		shopt -s nullglob failglob
		DSTDIR="$(ls -1d "${OUTDIR}"/grml_cd/boot/grml* | tail -1)"
		[[ -n "$DSTDIR" ]] && [[ -d "$DSTDIR" ]] || qwe "Error: no DSTDIR: $DSTDIR"
		XENH="$(ls -1 "${OUTDIR}"/grml_chroot/boot/xen-*.gz 2>/dev/null | sort -r | head -1)"
		if [[ -n "$XENH" ]]; then
			if [[ -r "$XENH" ]]; then
				rsync "$XENH" "${DSTDIR}"/xen
			else
				qwe "Error: could not copy XENH: $XENH"
			fi
		fi
		notice "copying VMLINUZ"
		VMLINUZ="$(ls -1 "${OUTDIR}"/grml_chroot/boot/vmlinuz-*-xen-* | sort -r | head -1)"
		[ -n "$VMLINUZ" ] || \
			VMLINUZ="$(ls -1 "${OUTDIR}"/grml_chroot/boot/vmlinuz-*bpo* | sort -r | head -1)"
		[[ -n "$VMLINUZ" ]] && [[ -r "$VMLINUZ" ]] || qwe "Error: no VMLINUZ: $VMLINUZ"
		rsync "$VMLINUZ" "${DSTDIR}"/linux26
		notice "copying INITRD"
		INITRD="$(ls -1 "${OUTDIR}"/grml_chroot/boot/initrd.img-*-xen-* | sort -r | head -1)"
		[ -n "$INITRD" ] || \
			INITRD="$(ls -1 "${OUTDIR}"/grml_chroot/boot/initrd.img-*bpo* | sort -r | head -1)"
		[[ -n "$INITRD" ]] && [[ -r "$INITRD" ]] || qwe "Error: no INITRD: $INITRD"
		rsync "$INITRD" "${DSTDIR}"/initrd.gz
		notice "END XENCOPY"
fi

resolvconf -u
# "${BASEDIR}/scripts/webserver.sh"
	# old:
	#declare WEBROOT="/var/www"
	#[[ -e "${WEBROOT}/${netintumclass}"  ]] || ln -s "${OUTDIR}/grml_cd" "${WEBROOT}/${netintumclass}"
