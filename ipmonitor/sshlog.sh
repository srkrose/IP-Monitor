#!/bin/bash

source /home/sample/scripts/dataset.sh

function ssh_log() {
	cat /var/log/secure | grep -ie "$(if (($(date -d '1 hour ago' +"%-d") < 10)); then date -d '1 hour ago' +"%b  %-d %H:"; else date -d '1 hour ago' +"%b %d %H:"; fi)" | grep -iv "pam_unix\|wp-toolkit\|127.0.0.1\|Bad protocol version\|sudo:" | grep "Invalid user\|Failed password for invalid user\|Did not receive identification string from\|Connection closed by" | awk '{for(i=1;i<=NF;i++) {if($i=="port") {if($6!="Did") printf "%-15s %-17s %-22s %-14s %-50s\n","DATE: "$1" "$2,"TIME: "$3,"IP: "$(i-1),"PORT: "$(i+1),"TYPE: "$6" "$7; else printf "%-15s %-17s %-22s %-14s %-50s\n","DATE: "$1" "$2,"TIME: "$3,"IP: "$(i-1),"PORT: "$(i+1),"TYPE: "$9" "$10}}}' | uniq -c >>$temp/sshlog_$time.txt
}

function static_ip() {
	if [ -r $temp/sshlog_$time.txt ] && [ -s $temp/sshlog_$time.txt ]; then
		staticip=($(cat $scripts/ipmonitor/staticip.txt))
		scount=${#staticip[@]}

		iplist=$(cat $temp/sshlog_$time.txt | awk '{print $8}' | sort | uniq)

		for ((i = 0; i < scount; i++)); do
			iplist=$(echo "$iplist" | grep -v "${staticip[i]}")
		done

		ips=($(echo "$iplist"))
		count=${#ips[@]}

		check_log
	fi
}

function check_log() {
	for ((i = 0; i < count; i++)); do
		search=$(whmapi1 read_cphulk_records list_name='black' | grep ${ips[i]})

		if [[ -z $search ]]; then
			data=$(cat $temp/sshlog_$time.txt | grep ${ips[i]})

			whois=$(sh $scripts/ipmonitor/iplookup.sh ${ips[i]})

			while IFS= read -r line; do
				printf "%-120s %-10s\n" "$line" "ID: $whois" >>$temp/failed-ssh_$time.txt
			done <<<"$data"
		fi
	done
}

function sort_log() {
	if [ -r $temp/failed-ssh_$time.txt ] && [ -s $temp/failed-ssh_$time.txt ]; then
		sortlog=$(cat $temp/failed-ssh_$time.txt | awk '{for (i=0;i<NF;i++) {if($i=="ID:" && $(i+1)!="") print}}' | sort -k5)

		if [[ ! -z $sortlog ]]; then
			echo "$sortlog" >>$svrlogs/cphulk/iplist/failed-ssh_$time.txt
		fi
	fi
}

function blacklist() {
	if [ -r $svrlogs/cphulk/iplist/failed-ssh_$time.txt ] && [ -s $svrlogs/cphulk/iplist/failed-ssh_$time.txt ]; then
		sh $scripts/cphulk/ipblacklist.sh failed-ssh
	fi
}

function summary() {
	sshlog=($(find $temp -type f -name "sshlog*" -exec ls -lat {} + | grep "$(date +"%F_%H:")" | head -1 | awk '{print $NF}'))

	if [ ! -z $sshlog ]; then
		count=$(wc -l $sshlog | awk '{print $1}')

		uniqipcount=$(cat $sshlog | awk '{print $8}' | sort | uniq | wc -l)

		failedssh=($(find $temp -type f -name "failed-ssh*" -exec ls -lat {} + | grep "$(date +"%F_%H:")" | head -1 | awk '{print $NF}'))

		if [ ! -z $failedssh ]; then
			newcount=$(wc -l $failedssh | awk '{print $1}')

			newuniqip=$(cat $failedssh | awk '{print $8}' | sort | uniq | wc -l)

			blacklist=($(find $svrlogs/cphulk/block -type f -name "sship-blacklisted*" -exec ls -lat {} + | grep "$(date +"%F_%H:")" | head -1 | awk '{print $NF}'))

			if [ ! -z $blacklist ]; then
				login=($(find $svrlogs/cphulk/iplist -type f -name "failed-ssh*" -exec ls -lat {} + | grep "$(date +"%F_%H:")" | head -1 | awk '{print $NF}'))

				listed=$(wc -l $login | awk '{print $1}')

				uniqlisted=$(cat $blacklist | grep "Total:" | awk '{print $2}')

				ip_data
			fi
		fi
	fi
}

function ip_data() {
	echo "SSH login failure count: $count" >>$svrlogs/ipmonitor/sshlog_$time.txt

	echo "SSH login failure unique IP count: $uniqipcount" >>$svrlogs/ipmonitor/sshlog_$time.txt

	echo "" >>$svrlogs/ipmonitor/sshlog_$time.txt

	echo "SSH new login failure count: $newcount" >>$svrlogs/ipmonitor/sshlog_$time.txt

	echo "SSH new login failure unique IP count: $newuniqip" >>$svrlogs/ipmonitor/sshlog_$time.txt

	echo "" >>$svrlogs/ipmonitor/sshlog_$time.txt

	echo "SSH login failure count (excluding LK): $listed" >>$svrlogs/ipmonitor/sshlog_$time.txt

	echo "Blacklisted unique IP count: $uniqlisted" >>$svrlogs/ipmonitor/sshlog_$time.txt

	echo "" >>$svrlogs/ipmonitor/sshlog_$time.txt

	cat $login >>$svrlogs/ipmonitor/sshlog_$time.txt
}

ssh_log

static_ip

sort_log

blacklist

summary
