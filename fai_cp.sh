#!/bin/bash
#Usage: fai_cp -s <source_dir> -o <chroot_dir> -c CLASS

VERB=1; # Verbose mode set to false on default

err() {
	echo -e "Error: $1 \n"
	exit 1
}

use_this() {
	echo 'Usage: fai_cp -s <source_dir> -o <chroot_dir> -c CLASS
	Avoid trailing slashes "/" in provided paths, anyway they will be stripped off
	
	# This script copies files from source directory into destination directory,
	# following class concept of FAI, that is,
	# $SDIR/foo -> $ODIR/foo/$CLASS
	# foo is a direcotry, $CLASS is a file with the content of an original foo.
	# Normally $ODIR is $FAI/files.
	# Note: At the moment the script does not allow for creating more than one versions of files for different classes'
}

erruse() {
	echo -e "Error: $1 \n"
	use_this
	exit 1
}


[ $# -eq 0 ] && erruse "Where the hell are arguments?"

while [ $1 ]; do #condition on non-empty string
case $1 in
	-s)
		shift
		SDIR=$(cd $1 && pwd)
		;;
	-o)
		shift
		ODIR=$(cd $1 && pwd)
		;;
	-c)
		shift
		CLASS=$1
		;;
	-v)
		VERB=0
		;;
	*)
		erruse "Smth goes wrong"
		;;
esac
shift
done

FILE=${ODIR}/${CLASS}_list

if [[ $VERB == 0 ]]; then
	echo "Parsed variables:
	List of made folders for subsequent use in fcopy will be stored...
	here 		    ---> $FILE
	Provided source dir ---> $SDIR 
	Provided output dir ---> $ODIR 
	Name of CLASS       ---> $CLASS"
fi

# Remove trailing / from paths as a sanity check
SDIR=$(echo "$SDIR" | sed "s=/\$==")
ODIR=$(echo "$ODIR" | sed "s=/\$==")

if ! find $SDIR -type f | sed "sQ^${SDIR}Q${ODIR}Q" | xargs -L 1 mkdir -p; then
	err "Failed to create directories corresponding to filenames to be copied"
fi

if ! find $SDIR -type f | sed "sQ^${SDIR}QQ" > $FILE; then
	err "Failed to create a file with list of directories in \$ODIR/${CLASS}_list"
fi

if ! find $SDIR -type f | sed -r -e "sQ^$SDIR[^;]*Q& &Q" -e "sQ ${SDIR}Q ${ODIR}Q" -e "sQ\$Q/${CLASS}Q" | xargs -L 1 cp -T -v; then
	err "Failed to copy files from $SDIR into $ODIR under relevant directories with their names set to $CLASS"
fi
exit 0 
