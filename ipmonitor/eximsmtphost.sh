#!/bin/bash

source /home/sample/scripts/dataset.sh

function smtphost_login() {
	cat /var/log/exim_mainlog | grep -ie "$(date -d '1 hour ago' +"%F %H:")" | grep "no host name found for IP address" | grep -v "127.0.0.1\|localhost" | awk '{printf "%-19s %-17s %-22s %-31s\n","DATE: "$1,"TIME: "$2,"IP: "$NF,"SMTPHOST: no_host_name_found"}' | sort | uniq -c >>$temp/nosmtphost_$time.txt
}

function static_ip() {
	if [ -r $temp/nosmtphost_$time.txt ] && [ -s $temp/nosmtphost_$time.txt ]; then
		staticip=($(cat $scripts/ipmonitor/staticip.txt))
		scount=${#staticip[@]}

		iplist=$(cat $temp/nosmtphost_$time.txt | awk '{print $7}' | sort | uniq)

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
			data=$(cat $temp/nosmtphost_$time.txt | grep ${ips[i]})

			whois=$(sh $scripts/ipmonitor/iplookup.sh ${ips[i]})

			while IFS= read -r line; do
				printf "%-90s %-10s\n" "$line" "ID: $whois" >>$temp/failed-smtphost_$time.txt
			done <<<"$data"
		fi
	done
}

function sort_log() {
	if [ -r $temp/failed-smtphost_$time.txt ] && [ -s $temp/failed-smtphost_$time.txt ]; then
		sortlog=$(cat $temp/failed-smtphost_$time.txt | awk '{for (i=0;i<NF;i++) {if($i=="ID:" && $(i+1)!="") print}}' | sort -nr)

		if [[ ! -z $sortlog ]]; then
			echo "$sortlog" >>$svrlogs/cphulk/iplist/failed-smtphost_$time.txt
		fi
	fi
}

function blacklist() {
	if [ -r $svrlogs/cphulk/iplist/failed-smtphost_$time.txt ] && [ -s $svrlogs/cphulk/iplist/failed-smtphost_$time.txt ]; then
		sh $scripts/cphulk/ipblacklist.sh failed-smtphost
	fi
}

function summary() {
	nosmtphost=($(find $temp -type f -name "nosmtphost*" -exec ls -lat {} + | grep "$(date +"%F_%H:")" | head -1 | awk '{print $NF}'))

	if [ ! -z $nosmtphost ]; then
		count=$(wc -l $nosmtphost | awk '{print $1}')

		uniqipcount=$(cat $nosmtphost | awk '{print $7}' | sort | uniq | wc -l)

		failedsmtphost=($(find $temp -type f -name "failed-smtphost*" -exec ls -lat {} + | grep "$(date +"%F_%H:")" | head -1 | awk '{print $NF}'))

		if [ ! -z $failedsmtphost ]; then
			newcount=$(wc -l $failedsmtphost | awk '{print $1}')

			newuniqip=$(cat $failedsmtphost | awk '{print $7}' | sort | uniq | wc -l)

			blacklist=($(find $svrlogs/cphulk/block -type f -name "smtphostip-blacklisted*" -exec ls -lat {} + | grep "$(date +"%F_%H:")" | head -1 | awk '{print $NF}'))

			if [ ! -z $blacklist ]; then
				login=($(find $svrlogs/cphulk/iplist -type f -name "failed-smtphost*" -exec ls -lat {} + | grep "$(date +"%F_%H:")" | head -1 | awk '{print $NF}'))

				listed=$(wc -l $login | awk '{print $1}')

				uniqlisted=$(cat $blacklist | grep "Total:" | awk '{print $2}')

				ip_data
			fi
		fi
	fi
}

function ip_data() {
	echo "Smtphost login failure count: $count" >>$svrlogs/ipmonitor/eximsmtphost_$time.txt

	echo "Smtphost login failure unique IP count: $uniqipcount" >>$svrlogs/ipmonitor/eximsmtphost_$time.txt

	echo "" >>$svrlogs/ipmonitor/eximsmtphost_$time.txt

	echo "Smtphost new login failure count: $newcount" >>$svrlogs/ipmonitor/eximsmtphost_$time.txt

	echo "Smtphost new login failure unique IP count: $newuniqip" >>$svrlogs/ipmonitor/eximsmtphost_$time.txt

	echo "" >>$svrlogs/ipmonitor/eximsmtphost_$time.txt

	echo "Smtphost login failure count (excluding LK): $listed" >>$svrlogs/ipmonitor/eximsmtphost_$time.txt

	echo "Blacklisted unique IP count: $uniqlisted" >>$svrlogs/ipmonitor/eximsmtphost_$time.txt

	echo "" >>$svrlogs/ipmonitor/eximsmtphost_$time.txt

	cat $login >>$svrlogs/ipmonitor/eximsmtphost_$time.txt
}

smtphost_login

static_ip

sort_log

blacklist

summary
