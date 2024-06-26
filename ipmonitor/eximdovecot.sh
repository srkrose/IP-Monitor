#!/bin/bash

source /home/sample/scripts/dataset.sh

function dovecot_login() {
	cat /var/log/exim_mainlog | grep -ie "$(date -d '1 hour ago' +"%F %H:")" | grep "Incorrect authentication data" | grep "set_id=" | grep -v "127.0.0.1\|localhost" | awk '{ip=""; email=""; for(i=1;i<=NF;i++) {if($i==535) {ip=$(i-1); gsub(/:.*/, "", ip); gsub(/\[|\]/, "", ip);} if($i~/set_id=/) { match($0, /\(set_id=[^)]*\)/); email=substr($0, RSTART+8, RLENGTH-9); gsub(/^ */, "", email);}} printf "%-19s %-17s %-22s %-22s %-50s\n","DATE: "$1,"TIME: "$2,"TYPE: "$3,"IP: "ip,"EMAIL: "email;}' | uniq -c >>$temp/dovecotlogin_$time.txt
}

function static_ip() {
	if [ -r $temp/dovecotlogin_$time.txt ] && [ -s $temp/dovecotlogin_$time.txt ]; then
		staticip=($(cat $scripts/ipmonitor/staticip.txt))
		scount=${#staticip[@]}

		iplist=$(cat $temp/dovecotlogin_$time.txt | awk '{print $9}' | sort | uniq)

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
			data=$(cat $temp/dovecotlogin_$time.txt | grep ${ips[i]})

			whois=$(sh $scripts/ipmonitor/iplookup.sh ${ips[i]})

			while IFS= read -r line; do
				printf "%-140s %-10s\n" "$line" "ID: $whois" >>$temp/failed-dovecot_$time.txt
			done <<<"$data"
		fi
	done
}

function sort_log() {
	if [ -r $temp/failed-dovecot_$time.txt ] && [ -s $temp/failed-dovecot_$time.txt ]; then
		sortlog=$(cat $temp/failed-dovecot_$time.txt | awk '{for (i=0;i<NF;i++) {if($i=="ID:" && $(i+1)!="") print}}' | sort -k6)

		if [[ ! -z $sortlog ]]; then
			echo "$sortlog" >>$svrlogs/cphulk/iplist/failed-dovecot_$time.txt
		fi
	fi
}

function blacklist() {
	if [ -r $svrlogs/cphulk/iplist/failed-dovecot_$time.txt ] && [ -s $svrlogs/cphulk/iplist/failed-dovecot_$time.txt ]; then
		sh $scripts/cphulk/ipblacklist.sh failed-dovecot
	fi
}

function summary() {
	dovecotlogin=($(find $temp -type f -name "dovecotlogin*" -exec ls -lat {} + | grep "$(date +"%F_%H:")" | head -1 | awk '{print $NF}'))

	if [ ! -z $dovecotlogin ]; then
		count=$(wc -l $dovecotlogin | awk '{print $1}')

		uniqipcount=$(cat $dovecotlogin | awk '{print $9}' | sort | uniq | wc -l)

		faileddovecot=($(find $temp -type f -name "failed-dovecot*" -exec ls -lat {} + | grep "$(date +"%F_%H:")" | head -1 | awk '{print $NF}'))

		if [ ! -z $faileddovecot ]; then
			newcount=$(wc -l $faileddovecot | awk '{print $1}')

			newuniqip=$(cat $faileddovecot | awk '{print $9}' | sort | uniq | wc -l)

			blacklist=($(find $svrlogs/cphulk/block -type f -name "dovecotip-blacklisted*" -exec ls -lat {} + | grep "$(date +"%F_%H:")" | head -1 | awk '{print $NF}'))

			if [ ! -z $blacklist ]; then
				login=($(find $svrlogs/cphulk/iplist -type f -name "failed-dovecot*" -exec ls -lat {} + | grep "$(date +"%F_%H:")" | head -1 | awk '{print $NF}'))

				listed=$(wc -l $login | awk '{print $1}')

				uniqlisted=$(cat $blacklist | grep "Total:" | awk '{print $2}')

				ip_data
			fi
		fi
	fi
}

function ip_data() {
	echo "Dovecot login failure count: $count" >>$svrlogs/ipmonitor/eximdovecot_$time.txt

	echo "Dovecot login failure unique IP count: $uniqipcount" >>$svrlogs/ipmonitor/eximdovecot_$time.txt

	echo "" >>$svrlogs/ipmonitor/eximdovecot_$time.txt

	echo "Dovecot new login failure count: $newcount" >>$svrlogs/ipmonitor/eximdovecot_$time.txt

	echo "Dovecot new login failure unique IP count: $newuniqip" >>$svrlogs/ipmonitor/eximdovecot_$time.txt

	echo "" >>$svrlogs/ipmonitor/eximdovecot_$time.txt

	echo "Dovecot login failure count (excluding LK): $listed" >>$svrlogs/ipmonitor/eximdovecot_$time.txt

	echo "Blacklisted unique IP count: $uniqlisted" >>$svrlogs/ipmonitor/eximdovecot_$time.txt

	echo "" >>$svrlogs/ipmonitor/eximdovecot_$time.txt

	cat $login >>$svrlogs/ipmonitor/eximdovecot_$time.txt
}

dovecot_login

static_ip

sort_log

blacklist

summary
