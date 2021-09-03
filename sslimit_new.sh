max_link=5

script_path=`realpath $0`
script_dir=`dirname $script_path`
traffic_dir="$script_dir/traffic"
ss_yml_path="$script_dir/docker-compose.yml"

container_list=`cat $ss_yml_path |grep container_name |grep -oP '(?<=:\s)ss_\w*'`

echo "--------------------------------"
mkdir -p $traffic_dir
TZ="Asia/Shanghai" date
for container in $container_list
do
	PID=`docker inspect -f '{{.State.Pid}}' $container`
	Container_IP=`docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $container`
	link_num=`nsenter -t $PID -n netstat -anp|grep ESTABLISHED |grep 8388 |awk '{print $5}'|awk -F ':' '{print $1}'|sort|uniq|wc -l`
	iptables -C DOCKER-USER -p tcp -d $Container_IP -j DROP > /dev/null 2>&1
	iptables_flag=`echo $?`
	#echo "$container link num is $link_num"
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
	if [ ! -e $traffic_dir/${container}_total ]
	then
		echo 0 > $traffic_dir/${container}_total
	fi
	if [ ! -e $traffic_dir/${container}_last ]
	then
		echo 0 > $traffic_dir/${container}_last
	fi
	total_sum=`cat $traffic_dir/${container}_total`
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
	echo $this_sum > $traffic_dir/${container}_last
	echo $total_sum > $traffic_dir/${container}_total
	echo "$container link num is $link_num,total $total_sum_gb GB,$total_sum_mb MB,$total_sum_kb KB"
done
iptables -L DOCKER-USER
