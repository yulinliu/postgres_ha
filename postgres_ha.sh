#!/bin/bash

SCRIPTNAME=`basename $0`
PIDFILE="/var/run/postgres_ha.pid"
LOG_FILE="/var/log/postgres_ha.log"

if [ -f "$PIDFILE" ]; then
	#verify if the process is actually still running under this pid
	OLDPID=`cat ${PIDFILE}`
	RESULT=`ps -ef | grep ${OLDPID} | grep ${SCRIPTNAME}`  

	if [ -n "${RESULT}" ]; then
		echo "Script already running!"
		exit 255
	fi
fi

PID=`ps -ef | grep ${SCRIPTNAME} | head -n1 |  awk ' {print $2;} '`
echo ${PID} > $PIDFILE

pgsql_bin="/usr/pgsql-9.3/bin"
pgsql_data="/var/lib/pgsql/9.3/data"
standby_file="$pgsql_data/recovery.conf"

ha_interface="eth2:ha"
ha_host="10.1.185.216"
ha_broadcast="10.1.191.255"
ha_netmask="255.255.248.0"
ha_route="10.1.0.1"

ha_host_status="N"

check_standby(){
	retval=""
	
	if [ -f "$standby_file" ];then
		retval="Y"
	else
		retval="N"
	fi
	
	echo "$retval"
}

check_postgres(){
	db_host=$1
	
	"$pgsql_bin/pg_isready" -p 5432 -h $db_host -t 10 -q; echo $?
}

start_ha_host(){
	if [ "$ha_host_status" == "N" ];then
		/sbin/ifconfig "$ha_interface" "$ha_host" broadcast "$ha_broadcast" netmask "$ha_netmask" up
		/sbin/route add -host "$ha_host" dev "$ha_interface"
		/sbin/arping -I "$ha_interface" -c 3 -s "$ha_host" "$ha_route" > /dev/null 2>&1
		ha_host_status="Y"
		
		echo "$(timestamp) start ha host interface" >> $LOG_FILE
	fi
}

stop_ha_host(){
	if [ "$ha_host_status" == "Y" ];then
		/sbin/ifconfig "$ha_interface" "$ha_host" broadcast "$ha_broadcast" netmask "$ha_netmask" down
		ha_host_status="N"
		
		echo "$(timestamp) stop ha host interface" >> $LOG_FILE
	fi
}

timestamp(){
	date "+%Y-%m-%d %H:%M:%S"
}

echo "$(timestamp) start postgres ha" >> $LOG_FILE

while true
do
	IS_Standby=$( check_standby )

#	echo "is standy: $IS_Standby"

	local_db_status=$( check_postgres "127.0.0.1" )
#	echo "local db status: $local_db_status"

	if [ "$local_db_status" == "0" ];then
		ha_db_ready="N"
		try=0
		try_max=5
		
		if [ "$IS_Standby" == "N" ];then
			try_max=3
		fi
		
		while [ $try -lt $try_max ]
		do
			ha_db_status=$( check_postgres "$ha_host" )
			try=$((${try}+1))
			
			if [ "$ha_db_status" == "0" ];then
				ha_db_ready="Y"
				break
			else
				echo "$(timestamp) ha db status: $ha_db_status" >> $LOG_FILE
			fi
		done
		
#		echo "ha db ready: $ha_db_ready"
		
		#handle ha host
		if [ "$ha_db_ready" == "N" ];then
			if [ "$IS_Standby" == "Y" ];then
				service postgresql-9.3 promote
				start_ha_host
			else
				start_ha_host
			fi
		fi

	else
		stop_ha_host
	fi

	sleep 5
done
