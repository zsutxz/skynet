#!/bin/sh
export ROOT=$(cd `dirname $0`; pwd)
export DAEMON=false

while getopts "Dk" arg
do
	case $arg in
		D)
		echo "DAMENO"
			export DAEMON=true
			;;
		k)
			killall $(ps -ef|grep skynet)
			#exit 0;
			;;
	esac
done

../skynet $ROOT/conf/config

