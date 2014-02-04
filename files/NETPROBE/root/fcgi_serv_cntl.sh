#!/bin/bash
#
# Wrapper for launching FastCGI backend
# Usage: fcgi_serv_cntl.sh (start|stop|restart)
# 
# Oleg Klyudt <oleg.kludt@gmail.com>
# Technical University of Munich, Chair of Network Architectures and Services
# September, 2012
#
set -u

err() {
	if [[ $# == 0 ]]; then
		echo "Error"
	else
		echo "Error: $1"
	fi
	exit 1
}

start() {

		if [[ $(ps -ef | grep 'rrd_processing' | wc -l) < 2 ]]; then
			sudo -u www-data python3.3 '/var/www/cgi-bin/rrd_processing.py' &>/dev/null &
		else 
			err "Cannot start more than one process! Stop the running one first"
		fi
}

stop() {

		num=$(ps -ef | grep 'rrd_processing' | awk '$1~/root/' | wc -l)
		if [[ $num > 1 ]]; then
			while [ $num -ne 1 ]
			do
				pid=$(ps -ef | grep 'rrd_processing' | awk '$1~/root/ {print $2; exit}')
				kill -s HUP $pid
				num=$(($num - 1))
			done
		else
			err "No running processes were found to be stopped"
		fi
}


[[ $# != 1 ]] && err "Missing argument: start, stop or restart"

case $1 in
	"start")
		start
		;;
	"stop")
		stop
		;;
	"restart")
		stop
		sleep 2
		start
		;;
	*)
		err "Provided argument cannot be recongnized. Try start, stop or restart"
esac

