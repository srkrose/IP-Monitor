#!/bin/bash

source /home/sample/scripts/dataset.sh

input=$1

function check_input() {

	if [[ $input == "failed-dovecot" ]]; then
		dovecot_blacklist
	
	elif [[ $input == "failed-smtphost" ]]; then
		smtphost_blacklist

	elif [[ $input == "failed-ftpd" ]]; then
		ftpd_blacklist

	elif [[ $input == "failed-ssh" ]]; then
		ssh_blacklist

	elif [[ $input == "fake-mail" ]]; then
		mail_blacklist

	elif [[ $input == "failed-attempt" ]]; then
		login_blacklist

	elif [[ $input == "cptemp-block" ]]; then
		cphulk_blacklist

	fi
}

function check_file() {
	username=$(echo "$ipblacklist" | awk -F'/' '{print $NF}' | awk -F'_' '{print $1}')

	if [[ $username == "failed-dovecot" ]]; then
		filename="dovecotip"

		ips=($(cat $ipblacklist | awk '{print $5}' | sort | uniq))

	elif [[ $username == "failed-smtphost" ]]; then
		filename="smtphostip"

		ips=($(cat $ipblacklist | awk '{print $5}' | sort | uniq))

	elif [[ $username == "failed-ftpd" ]]; then
		filename="ftpdip"

		ips=($(cat $ipblacklist | awk '{print $6}' | sort | uniq))

	elif [[ $username == "failed-ssh" ]]; then
		filename="sship"

		ips=($(cat $ipblacklist | awk '{print $7}' | sort | uniq))

	elif [[ $username == "fake-mail" ]]; then
		filename="mailip"

		ips=($(cat $ipblacklist | awk '{print $8}' | sort | uniq))

	elif [[ $username == "failed-attempt" ]]; then
		filename="loginip"

		ips=($(cat $ipblacklist | awk '{print $9}' | sort | uniq))

	elif [[ $username == "cptemp-block" ]]; then
		filename="cphulkip"

		ips=($(cat $ipblacklist | awk '{print $9}' | sort | uniq))
	fi
}

function check_data() {
	if [[ $username == "failed-dovecot" ]]; then
		line=$(cat $ipblacklist | grep ${ips[i]} | head -1)
		ip=${ips[i]}
		comment=$(echo "$line" | awk '{print $7" "$9}')

	elif [[ $username == "failed-smtphost" ]]; then
		line=$(cat $ipblacklist | grep ${ips[i]} | head -1)
		ip=${ips[i]}
		comment=$(echo "$line" | awk '{print $7" "$9}')

	elif [[ $username == "failed-ftpd" ]]; then
		line=$(cat $ipblacklist | grep ${ips[i]} | head -1)
		ip=${ips[i]}
		comment=$(echo "$line" | awk '{print $8" "$10}')

	elif [[ $username == "failed-ssh" ]]; then
		line=$(cat $ipblacklist | grep ${ips[i]} | head -1)
		ip=${ips[i]}
		comment=$(echo "$line" | awk '{print $9" "$14}')

	elif [[ $username == "fake-mail" ]]; then
		line=$(cat $ipblacklist | grep ${ips[i]} | head -1)
		ip=${ips[i]}
		comment=$(echo "$line" | awk '{print $10" "$12}')

	elif [[ $username == "failed-attempt" ]]; then
		line=$(cat $ipblacklist | grep ${ips[i]} | head -1)
		ip=${ips[i]}
		comment=$(echo "$line" | awk '{print $11" "$13}')

	elif [[ $username == "cptemp-block" ]]; then
		line=$(cat $ipblacklist | grep ${ips[i]} | head -1)
		ip=${ips[i]}
		comment=$(echo "$line" | awk '{print $11" "$13}')
	fi
}

function ip_blacklist() {

	check_file

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

function dovecot_blacklist() {
	ipblacklist=$(find $svrlogs/cphulk/iplist -type f -name "failed-dovecot*" -exec ls -lat {} + | grep "$(date +"%F_%H:")" | head -1 | awk '{print $NF}')

	if [ ! -z $ipblacklist ]; then
		ip_blacklist
	fi
}

function smtphost_blacklist() {
	ipblacklist=$(find $svrlogs/cphulk/iplist -type f -name "failed-smtphost*" -exec ls -lat {} + | grep "$(date +"%F_%H:")" | head -1 | awk '{print $NF}')

	if [ ! -z $ipblacklist ]; then
		ip_blacklist
	fi
}

function ftpd_blacklist() {
	ipblacklist=$(find $svrlogs/cphulk/iplist -type f -name "failed-ftpd*" -exec ls -lat {} + | grep "$(date +"%F_%H:")" | head -1 | awk '{print $NF}')

	if [ ! -z $ipblacklist ]; then
		ip_blacklist
	fi
}

function ssh_blacklist() {
	ipblacklist=$(find $svrlogs/cphulk/iplist -type f -name "failed-ssh*" -exec ls -lat {} + | grep "$(date +"%F_%H:")" | head -1 | awk '{print $NF}')

	if [ ! -z $ipblacklist ]; then
		ip_blacklist
	fi
}

function mail_blacklist() {
	ipblacklist=$(find $svrlogs/cphulk/iplist -type f -name "fake-mail*" -exec ls -lat {} + | grep "$(date +"%F_%H:")" | head -1 | awk '{print $NF}')

	if [ ! -z $ipblacklist ]; then
		ip_blacklist
	fi
}

function login_blacklist() {
	ipblacklist=$(find $svrlogs/cphulk/iplist -type f -name "failed-attempt*" -exec ls -lat {} + | grep "$(date +"%F_%H:")" | head -1 | awk '{print $NF}')

	if [ ! -z $ipblacklist ]; then
		ip_blacklist
	fi
}

function cphulk_blacklist() {
	ipblacklist=$(find $svrlogs/cphulk/iplist -type f -name "cptemp-block*" -exec ls -lat {} + | grep "$(date +"%F_%H:")" | head -1 | awk '{print $NF}')

	if [ ! -z $ipblacklist ]; then
		ip_blacklist
	fi
}

check_input
