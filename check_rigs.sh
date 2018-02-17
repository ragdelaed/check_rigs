#/bin/bash

hostname=$(hostname)
maintenance_hosts=("r1_15")

for pid in $(ps -ef|grep r1|awk '{print $2}')
do 	
	echo killing $pid
	kill -9 $pid; 
done
rigs=$(grep r1 /etc/hosts|awk '{print $2}')
echo $rigs

reboot_rig () {

rack_loc=$1
rig_on=$(grep $rack_loc /root/codesend_codes |grep on|cut -f 3 -d ,)
rig_off=$(grep $rack_loc /root/codesend_codes |grep off|cut -f 3 -d ,)

echo $hostname - rebooting $rack_loc

for x in `seq 10`; do $rig_off; done
sleep 20
for x in `seq 10`; do $rig_on; done
sleep 20

}

for rig in $(echo $rigs)
do
	if [[ " ${maintenance_hosts[@]} " =~ " $rig " ]]; then
		echo matched maintenance, moving on
		echo 
		continue
	fi	

	echo checking $rig ping
	/usr/bin/fping -c1 -t300 $rig 2>/dev/null 1>/dev/null
	if [ "$?" = 0 ]
	then
		echo "Host $rig found"
	else
		logger "$hostname - rebooting $rig due to no ping"
		echo -e  "$hostname - rebooting $rig due to no ping"|mail -s "$hostname - rebooting $rig due to no ping" ragdelaed@ragdelaed.com
		reboot_rig $rig
	fi


	echo checking $rig memstate
	mem_state=$(ssh -o ConnectTimeout=10 $rig "show stats|grep memstates|grep -c 0")
	if [ "$mem_state" = "1" ]
	then
		logger "$hostname - rebooting $rig due to memstate issue"
		echo -e  "$hostname - rebooting $rig due to memstate issue"|mail -s "$hostname - rebooting $rig due to memstate" ragdelaed@ragdelaed.com
		reboot_rig $rig
	elif [ -z "$mem_state" ]
	then
		logger "$hostname - rebooting $rig due to ssh timeout"
		echo -e  "$hostname - rebooting $rig due to ssh timeout"|mail -s "$hostname - rebooting $rig due to ssh timeout" ragdelaed@ragdelaed.com
		reboot_rig $rig
		
	fi

	echo clearing thermals and throttles
	ssh -o ConnectTimeout=10 $rig "clear-thermals"


done

