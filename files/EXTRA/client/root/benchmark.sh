#!/bin/bash
SERV1="http://10.0.1.50"
SERV2="http://10.0.2.50"
[ -d ./trash ] || mkdir ./trash
while [[ $(date +%H) != 22 ]]; do
	wget ${SERV1}/dump -O ./trash/dump1 &>/dev/null &
	wget ${SERV1}/dump -O ./trash/dump2 &>/dev/null &
	wget ${SERV1}/dump -O ./trash/dump3 &>/dev/null &
	wget ${SERV1}/dump -O ./trash/dump4 &>/dev/null &
	wget ${SERV2}/dump -O ./trash/dump5 &>/dev/null &
	wget ${SERV2}/dump -O ./trash/dump6 &>/dev/null &
	wget ${SERV2}/dump -O ./trash/dump7 &>/dev/null &
	wget ${SERV2}/dump -O ./trash/dump8 &>/dev/null &
	wait
	echo "Iteration $i is done"
done
echo 'All iterations are done'
