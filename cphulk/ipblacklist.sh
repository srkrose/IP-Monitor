#!/bin/bash

source /home/sample/scripts/dataset.sh

input=$1

function check_iplist() {
	ipblacklist=$(find $svrlogs/cphulk/iplist -type f -name "$input*" -exec ls -lat {} + | grep "$(date +"%F_%H:")" | head -1 | awk '{print $NF}')

	if [ ! -z $ipblacklist ]; then
		ip_blacklist
	fi
}

function ip_blacklist() {
	username=$(echo "$ipblacklist" | awk -F'/' '{print $NF}' | awk -F'_' '{print $1}')

	ips=($(cat $ipblacklist | awk '{for (i=0;i<NF;i++) {if($i=="IP:") print $(i+1)}}' | sort | uniq))

	ipcount=${#ips[@]}

	num=0

	for ((i = 0; i < ipcount; i++)); do
		check_data

		search=$(whmapi1 read_cphulk_records list_name='black' | grep "$ip")

		if [[ -z $search ]]; then
			result=$(whmapi1 create_cphulk_record list_name='black' ip=$ip comment="$comment" | grep -i "result:" | awk '{print $2}')
			num=$((num + 1))

			if [ "$result" -eq 1 ]; then
				echo "$num - Blacklisted: $ip" >>$svrlogs/cphulk/block/$filename-blacklisted_$time.txt
			else
				echo "$num - Failed: $ip" >>$svrlogs/cphulk/block/$filename-blacklisted_$time.txt
			fi
		fi
	done

	echo "Total: $num" >>$svrlogs/cphulk/block/$filename-blacklisted_$time.txt
	echo "" >>$svrlogs/cphulk/block/$filename-blacklisted_$time.txt
}

function check_data() {
	line=$(cat $ipblacklist | grep ${ips[i]} | head -1)
	ip=${ips[i]}
	ccode=$(echo "$line" | awk '{for (i=0;i<NF;i++) {if($i=="ID:") print $(i+1)}}')

	if [[ $username == "failed-smtphost" ]]; then
		condata=$(echo "$line" | awk -F'SMTPHOST: | ID:' '/SMTPHOST:/ {print $2}' | sed 's/^[[:space:]]*//')
		filename="smtphostip"

	elif [[ $username == "failed-ftpd" ]]; then
		condata=$(echo "$line" | awk -F'USER: | ID:' '/USER:/ {print $2}' | sed 's/^[[:space:]]*//')
		filename="ftpdip"

	elif [[ $username == "failed-ssh" ]]; then
		condata=$(echo "$line" | awk -F'PORT: | TYPE:' '/PORT:/ {print $2}' | sed 's/^[[:space:]]*//')
		filename="sship"

	elif [[ $username == "failed-dovecot" ]]; then
		condata=$(echo "$line" | awk -F'EMAIL: | ID:' '/EMAIL:/ {print $2}' | sed 's/^[[:space:]]*//')
		filename="dovecotip"

	elif [[ $username == "cptemp-block" ]]; then
		condata=$(echo "$line" | awk -F'USER: | ID:' '/USER:/ {print $2}' | sed 's/^[[:space:]]*//')
		filename="cphulkip"

	elif [[ $username == "fake-mail" ]]; then
		condata=$(echo "$line" | awk -F'USER: | ID:' '/USER:/ {print $2}' | sed 's/^[[:space:]]*//')
		filename="mailip"

	elif [[ $username == "failed-attempt" ]]; then
		condata=$(echo "$line" | awk -F'USER: | ID:' '/USER:/ {print $2}' | sed 's/^[[:space:]]*//')
		filename="loginip"

	fi

	comment=$(echo "$condata $ccode")
}

check_iplist
