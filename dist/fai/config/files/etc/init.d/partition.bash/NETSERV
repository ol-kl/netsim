#!/bin/bash
# This script creates partitions for persistent system, given 
# there no of them already and HDD has enough space for 2 partitions (10 GB and 5 GB)
#set -x
# Checking for partition labels

SCRIPTNAME=$(basename "$0")
DIR=$(dirname $(readlink -f "$0"))
LABELDIR='/dev/disk/by-label'
declare -A PARTTBL
SECTOR=-5

err() {
if [ -n "$1" ]; then
	echo "Error in ${SCRIPTNAME}: $1"
else 
	echo "Error in ${SCRIPTNAME} occured"
fi
echo "==================================================
Automatic creation of partitions for persistency failed.
Consider the reason and either run script again manually, or 
create required partition manually.
There must exist two partitions:
1. size: 10 GB	label: live-rw fs-type: ext3
2. size: 5 GB	label: home-rw fs-type: ext3

At the current state system cannot enjoy persistent feature,
that means no preservation of changes have been made and 
files have been created or modified
"
exit 1
}

ext() {
if [ -n "$1" ]; then
	echo "Graceful exit in ${SCRIPTNAME}: $1"
else 
	echo "Graceful exit in ${SCRIPTNAME}: no errors"
fi
exit 0
}

[ -d $LABELDIR ] && [ -e ${LABELDIR}/live-rw -o -L ${LABELDIR}/live-rw ] && \
	[ -e ${LABELDIR}/home-rw -o -L ${LABELDIR}/home-rw ] && ext "required partitions exist"

! [ -e ${DIR}/partition.awk ] && err "The parser script partition.awk is missing in the directory, where \
	the $SCRIPTNAME is invoked from. Script was aborted."

echo "Required partitions weren't found, proceeding with existing HDDs analysis..." 

HDD=$(parted -lm | grep -o -e '/dev/sd[a-z]') # check here alignment of $HDD entries, if with \n - the HDDN stanza can be simplified
[ -n "$HDD" ] && echo -e "The following HDDs were detected: \n$HDD "
[ -z "$HDD" ] && err "Do you have any HDDs in the system?"

HDDN=$(parted -lm | grep -o -e '/dev/sd[a-z]' | wc -w -l | awk '{if ($1 > $2) {print $1} else {print $2}}') # number of detected solid drives shown by parted

if $(echo "$HDD" | grep ' '); then # $HDD string words are separated with spaces
	for i in $(seq ${HDDN}); do
		HDDLIST[${i}]=$(echo "$HDD" | cut -d " " -f ${i})
	done
else # then they are separated by \n or only one HDD exists

	for i in $(seq ${HDDN}); do
		HDDLIST[${i}]=$(echo "$HDD" | awk "{if (NR == ${i}) {print \$0} }")
	done
fi

echo "HDDLIST contains values: 
${HDDLIST[*]}"
#exit 0
# make here test on array values


for i in $(seq ${HDDN}); do
	# PARTTBL is associative array holding [hdd_name] and values as either negative meaning there is no space on HDD, 
	# or positive, standing for a position on HDD, where new partitions can be written from. Position is expressen in MB (megabytes)
	# and intented for use solely with 'parted' utility. The lower positive value, the more free space a HDD has. In case of 
	# empty HDD without partitions the value will be 1. These ones are of highest priority in our approach.
	TMP=$( parted -m ${HDDLIST[${i}]} unit "MB" print | awk -f ${DIR}/partition.awk | cut -d ":" -f 2 ) 
	if (( $TMP > 0 )); then
		[[ $SECTOR == -5 || $TMP < $SECTOR ]] && SECTOR=$TMP && HDDS=${HDDLIST[${i}]}
#		(( $TMP < $SECTOR )) && (SECTOR=$TMP; HDDS=${HDDLIST[${i}]} )
	fi
	PARTTBL[${HDDLIST[${i}]}]=$TMP 
	[[ $TMP == 1 ]] && break # Make sure, that first empty HDD is chosen for our purposes
done

echo "HDDS: $HDDS"
[ -z $HDDS ] && err "\$HDDS was not set"
[[ $SECTOR < 1 ]] && ext "Sector for partitioning to srart with was not set. Most likely due to lack of space on current HDDs"

echo "$HDDS was selected as a target HDD with enough space, partitioning will start on ${SECTOR}'th MB of disk"
#exit 0
# Here follows lines to execute parted, mkfs.ext3 and labeling + check results
# Make changes in /etc/fstab is not necessary, because live-initramfs takes care of detecting and mounting persistent partitions

[[ $SECTOR -eq 1 ]] || declare $(parted "${HDDS}" unit "MB" print | tail -n +5 | \
	awk 'BEGIN {OFS="="} /(primary|extended|logical)/ { types[$5]++ } END {for (i in types) {print i, types[i]}}' | \
	tr "[a-z]" "[A-Z]")
# this one declares variables: LOGICAL, EXTENDED, PRIMARY equal to number of found partition types on a given HDD. Otherwise they are set to 0.
LOGICAL=${LOGICAL:=0}
PRIMARY=${PRIMARY:=0}
EXTENDED=${EXTENDED:=0}

# Here: only empty disk can have no partitions
[[ $SECTOR -ne 1 ]] && [[ $LOGICAL == 0 && $PRIMARY == 0  && $EXTENDED == 0 ]] && err "internal error, number of partitions type was set wrong"

#exit 0
if [[ $LOGICAL == 0 && $EXTENDED == 0 ]]; then
	parted -s $HDDS unit "MB" mkpart extended $SECTOR $(($SECTOR + 15000)) || err "parted error: extended partition creation"
	parted -s $HDDS unit "MB" mkpart logical $(($SECTOR + 1)) $(($SECTOR + 5000)) || err "parted error: logical partition of size 5GB creation"
	parted -s $HDDS unit "MB" mkpart logical $(($SECTOR + 5001)) $(($SECTOR + 14999)) || err "parted error: logical partition of size 10GB creation"

	#extraction of numbers assigned to new created patitions
	declare $(parted $HDDS unit "MB" print | head -n -1 | tail -n 2 | awk 'BEGIN {OFS="="} {if (NR == 1) {print "PART_HOME", $1}} {if (NR == 2) {print "PART_LIVE", $1}}')
	PART_HOME="${HDDS}${PART_HOME}"
	PART_LIVE="${HDDS}${PART_LIVE}"
	echo "home and live partitions: $PART_HOME $PART_LIVE"
	mkfs.ext3 -L home-rw $PART_HOME || err "failed to make FS of ext3 type on $PART_HOME and assign a label home-rw"
	mkfs.ext3 -L live-rw $PART_LIVE || err "failed to myke FS of ext3 type on $PART_LIVE and assign a label live-rw"
	ext "New partitions were successfully created"
else
	ext "Logical volumes on current HDD were found. It means that additional logical partitions are to be created within 
	extended volume. At the moment the script $SCRIPTNAME cannot correctly calculate sector ranges for these new partitions."
fi


