#!/bin/awk -f
# This script scans for all available HDD in system and tries to find one either unmapped yet (empty)
# or having enough space to create two partitions required for persistence feature of live systems
# Currently [live-rw] = 10 GB, [homr-rw] = 5 GB

BEGIN {
	FS=":";
	RS=";";
	ENDS=0;
# 	$HDDN and $HDDL are passed here by calling script	
}

#looking for records with HDD names: /dev/sd*
/\/dev\/sd/ {
	HDD=$1;
	#getting size of HDD in MB and strip off 'MB' suffix
	SIZE=substr($2,1,length($2)-2);
}

!/\/dev\/sd/ {
	if ($1 != "BYT") {
		if (NF < 6) { # EOF
			exit 
			}
		ENDtmp=substr($3,1,length($3)-2);
		if (ENDtmp > ENDS) { ENDS=ENDtmp }
	}
}

END {
	if (ENDS != 0) {
		if (SIZE - ENDS > 15000) { print "START:" ENDS+1 }
		else { print "NOSPACE:-1"}
		}
	else {
		print "EMPTY:1"
		}
}

