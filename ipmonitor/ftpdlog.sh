#!/bin/bash

source /home/sample/scripts/dataset.sh

function ftpd_log() {
	cat /var/log/messages | grep -ie "$(if (($(date -d '1 hour ago' +"%-d") < 10)); then date -d '1 hour ago' +"%b  %-d %H:"; else date -d '1 hour ago' +"%b %d %H:"; fi)" | grep "pure-ftpd:" | grep "Authentication failed for user" | awk '{print $1,$2,$6,$NF}' | sed 's/(?@//;s/)//;s/[][]//g' | awk '{printf "%-15s %-22s %-50s\n","DATE: "$1" "$2,"IP: "$3,"USER: "$NF}' | sort | uniq -c | sort -k8 >>$temp/ftpdlog_$time.txt
}

function static_ip() {
	if [ -r $temp/ftpdlog_$time.txt ] && [ -s $temp/ftpdlog_$time.txt ]; then
		staticip=($(cat $scripts/ipmonitor/staticip.txt))
		scount=${#staticip[@]}

		iplist=$(cat $temp/ftpdlog_$time.txt | awk '{print $6}' | sort | uniq)

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
			data=$(cat $temp/ftpdlog_$time.txt | grep ${ips[i]})

			whois=$(sh /home/rlksvrlogs/scripts/ipmonitor/iplookup.sh ${ips[i]})

			while IFS= read -r line; do
				printf "%-90s %-10s\n" "$line" "ID: $whois" >>$temp/failed-ftpd_$time.txt
			done <<<"$data"
		fi
	done
}

function sort_log() {
	if [ -r $temp/failed-ftpd_$time.txt ] && [ -s $temp/failed-ftpd_$time.txt ]; then
		sortlog=$(cat $temp/failed-ftpd_$time.txt | awk '{if($10!="") print}' | sort -k8)

		if [[ ! -z $sortlog ]]; then
			echo "$sortlog" >>$svrlogs/cphulk/iplist/failed-ftpd_$time.txt
		fi
	fi
}

function blacklist() {
	if [ -r $svrlogs/cphulk/iplist/failed-ftpd_$time.txt ] && [ -s $svrlogs/cphulk/iplist/failed-ftpd_$time.txt ]; then
		sh $scripts/cphulk/ipblacklist.sh failed-ftpd
	fi
}

function summary() {
	ftpdlog=($(find $temp -type f -name "ftpdlog*" -exec ls -lat {} + | grep "$(date +"%F_%H:")" | head -1 | awk '{print $NF}'))

	if [ ! -z $ftpdlog ]; then
		count=$(wc -l $ftpdlog | awk '{print $1}')

		uniqipcount=$(cat $ftpdlog | awk '{print $6}' | sort | uniq | wc -l)

		failedftpd=($(find $temp -type f -name "failed-ftpd*" -exec ls -lat {} + | grep "$(date +"%F_%H:")" | head -1 | awk '{print $NF}'))

		if [ ! -z $failedftpd ]; then
			newcount=$(wc -l $failedftpd | awk '{print $1}')

			newuniqip=$(cat $failedftpd | awk '{print $6}' | sort | uniq | wc -l)

			blacklist=($(find $svrlogs/cphulk/block -type f -name "ftpdip-blacklisted*" -exec ls -lat {} + | grep "$(date +"%F_%H:")" | head -1 | awk '{print $NF}'))

			if [ ! -z $blacklist ]; then
				login=($(find $svrlogs/cphulk/iplist -type f -name "failed-ftpd*" -exec ls -lat {} + | grep "$(date +"%F_%H:")" | head -1 | awk '{print $NF}'))

				listed=$(wc -l $login | awk '{print $1}')

				uniqlisted=$(cat $blacklist | grep "Total:" | awk '{print $2}')

				ip_data
			fi
		fi
	fi
}

function ip_data() {
	echo "Pure-FTPD login failure count: $count" >>$svrlogs/ipmonitor/ftpdlog_$time.txt

	echo "Pure-FTPD login failure unique IP count: $uniqipcount" >>$svrlogs/ipmonitor/ftpdlog_$time.txt

	echo "" >>$svrlogs/ipmonitor/ftpdlog_$time.txt

	echo "Pure-FTPD new login failure count: $newcount" >>$svrlogs/ipmonitor/ftpdlog_$time.txt

	echo "Pure-FTPD new login failure unique IP count: $newuniqip" >>$svrlogs/ipmonitor/ftpdlog_$time.txt

	echo "" >>$svrlogs/ipmonitor/ftpdlog_$time.txt

	echo "Pure-FTPD login failure count (excluding LK): $listed" >>$svrlogs/ipmonitor/ftpdlog_$time.txt

	echo "Blacklisted unique IP count: $uniqlisted" >>$svrlogs/ipmonitor/ftpdlog_$time.txt

	echo "" >>$svrlogs/ipmonitor/ftpdlog_$time.txt

	cat $login >>$svrlogs/ipmonitor/ftpdlog_$time.txt
}

ftpd_log

static_ip

sort_log

blacklist

summary
