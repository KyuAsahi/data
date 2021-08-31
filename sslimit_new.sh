#!/bin/bash

local_path=`pwd`
ss_yml_path="$local_path/docker-compose.yml"
container_list=`cat $ss_yml_path |grep container_name |grep -oP '(?<=:\s)ss_\w*'`
max_link=5

while [ ! ]
do
	echo "--------------------------------"
	date
	for container in $container_list
	do
		PID=`docker inspect -f '{{.State.Pid}}' $container`
		Container_IP=`docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $container`
		link_num=`nsenter -t $PID -n netstat -anp|grep ESTABLISHED |grep 8388 |awk '{print $5}'|awk -F ':' '{print $1}'|sort|uniq|wc -l`
		iptables -C DOCKER-USER -p tcp -d $Container_IP -j DROP
		iptables_flag=`echo $?`
		echo "$container link num is $link_num"
		if [ $link_num -gt $max_link ]
		then
			if [ $iptables_flag -eq 1 ]
			then
			iptables -I DOCKER-USER -p tcp -d $Container_IP -j DROP
			fi
		else
			if [ $iptables_flag -eq 0 ]
			then
			iptables -D DOCKER-USER -p tcp -d $Container_IP -j DROP
			fi
		fi
	done
	sleep 600
done
