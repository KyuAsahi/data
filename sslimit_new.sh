#!/bin/bash

max_link=5

script_path=`realpath $0`
script_dir=`dirname $script_path`
month_now=`TZ="Asia/Shanghai" date +%Y-%m`
traffic_dir="$script_dir/traffic"
traffic_date_dir="$traffic_dir/$month_now"
ss_yml_path="$script_dir/docker-compose.yml"


function Traffic_statistics(){

	mkdir -p $traffic_date_dir
	if [ ! -e $traffic_date_dir/${container}_total ]
	then
		echo 0 > $traffic_date_dir/${container}_total
	fi
	if [ ! -e $traffic_dir/${container}_last ]
	then
		echo 0 > $traffic_dir/${container}_last
	fi
	total_sum=`cat $traffic_date_dir/${container}_total`
	last_sum=`cat $traffic_dir/${container}_last`
	this_sum=`cat /proc/$PID/net/dev |grep eth0| awk '{print $10}'`
	if [ $this_sum -ge $last_sum ]
	then
		dif=`expr $this_sum - $last_sum`
	else
		dif=`expr $this_sum - 0`
	fi
	total_sum=`expr $total_sum + $dif`
	total_sum_kb=`expr $total_sum / 1024`
	total_sum_mb=`expr $total_sum_kb / 1024`
	total_sum_gb=`expr $total_sum_mb / 1024`
	echo $total_sum > $traffic_date_dir/${container}_total
	echo $this_sum > $traffic_dir/${container}_last
	
}

function Connection_control(){

	container_list=`cat $ss_yml_path |grep container_name |grep -oP '(?<=:\s)ss_\w*'`
	
	for container in $container_list
	do
		PID=`docker inspect -f '{{.State.Pid}}' $container`
		Container_IP=`docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $container`
		link_list=`nsenter -t $PID -n netstat -anp|grep ESTABLISHED |grep 8388 |awk '{print $5}'|awk -F ':' '{print $1}'|sort|uniq`
		link_num=`echo "$link_list"|wc -l`
		iptables -C DOCKER-USER -p tcp -d $Container_IP -j DROP > /dev/null 2>&1
		iptables_flag=`echo $?`
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
		Traffic_statistics
		echo "$container $link_num link , $total_sum_gb GB , $total_sum_mb MB , $total_sum_kb KB"
		echo "$link_list"
	done
	
}

function main(){

	echo "--------------------------------"
	TZ="Asia/Shanghai" date
	Connection_control
	iptables -L DOCKER-USER
	
}

main

