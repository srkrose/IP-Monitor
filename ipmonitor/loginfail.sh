#!/bin/bash

source /home/sample/scripts/dataset.sh

function login_log() {
	cat /usr/local/cpanel/logs/login_log | grep -ie "$(date -d '1 hour ago' +"%F %H:")" | grep "FAILED LOGIN" | awk '{printf "%-19s %-17s %-19s %-13s %-22s %-50s\n","DATE: "$1,"TIME: "$2,"LOGIN: "$5,"TYPE: "$9,"IP: "$6,"USER: "$8}' | sed 's/[][]//g;s/"//g' | uniq -c >>$temp/loginfail_$time.txt
}

function static_ip() {
	if [ -r $temp/loginfail_$time.txt ] && [ -s $temp/loginfail_$time.txt ]; then
		staticip=($(cat $scripts/ipmonitor/staticip.txt))
		scount=${#staticip[@]}

		iplist=$(cat $temp/loginfail_$time.txt | awk '{print $11}' | sort | uniq)

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
			data=$(cat $temp/loginfail_$time.txt | grep ${ips[i]})

			whois=$(sh $scripts/ipmonitor/iplookup.sh ${ips[i]})

			while IFS= read -r line; do
				printf "%-150s %-10s\n" "$line" "ID: $whois" >>$temp/failed-login_$time.txt
			done <<<"$data"
		fi
	done
}

function mail_check() {
	if [ -r $temp/failed-login_$time.txt ] && [ -s $temp/failed-login_$time.txt ]; then
		while IFS= read -r line || [[ -n "$line" ]]; do
			email=$(echo "$line" | awk '{print $11}')

			if [[ $email == *[@]* ]]; then
				domain=$(echo "$email" | awk -F'@' '{print $2}')
				username=$(whmapi1 getdomainowner domain=$domain | grep -i "user:" | awk '{print $2}')

				if [[ "$username" != "~" ]]; then
					status=$(uapi --user=$username Mailboxes get_mailbox_status_list account=$email | grep -i "status:" | awk '{print $2}')

					if [ "$status" -eq 0 ]; then
						echo "$line" >>$temp/failed-attempt_$time.txt
					fi
				else
					echo "$line" >>$temp/failed-attempt_$time.txt
				fi
			else
				echo "$line" >>$temp/failed-attempt_$time.txt
			fi

		done <"$temp/failed-login_$time.txt"
	fi
}

function sort_log() {
	if [ -r $temp/failed-attempt_$time.txt ] && [ -s $temp/failed-attempt_$time.txt ]; then
		sortlog=$(cat $temp/failed-attempt_$time.txt | awk '{for (i=0;i<NF;i++) {if($i=="ID:" && $(i+1)!="") print}}' | sort -k11)

		if [[ ! -z $sortlog ]]; then
			echo "$sortlog" >>$svrlogs/cphulk/iplist/failed-attempt_$time.txt
		fi
	fi
}

function blacklist() {
	if [ -r $svrlogs/cphulk/iplist/failed-attempt_$time.txt ] && [ -s $svrlogs/cphulk/iplist/failed-attempt_$time.txt ]; then
		sh $scripts/cphulk/ipblacklist.sh failed-attempt
	fi
}

function summary() {
	loginfail=($(find $temp -type f -name "loginfail*" -exec ls -lat {} + | grep "$(date +"%F_%H:")" | head -1 | awk '{print $NF}'))

	if [ ! -z $loginfail ]; then
		count=$(wc -l $loginfail | awk '{print $1}')

		uniqipcount=$(cat $loginfail | awk '{print $11}' | sort | uniq | wc -l)

		failedlogin=($(find $temp -type f -name "failed-login*" -exec ls -lat {} + | grep "$(date +"%F_%H:")" | head -1 | awk '{print $NF}'))

		if [ ! -z $failedlogin ]; then
			newcount=$(wc -l $failedlogin | awk '{print $1}')

			newuniqip=$(cat $failedlogin | awk '{print $11}' | sort | uniq | wc -l)

			blacklist=($(find $svrlogs/cphulk/block -type f -name "loginip-blacklisted*" -exec ls -lat {} + | grep "$(date +"%F_%H:")" | head -1 | awk '{print $NF}'))

			if [ ! -z $blacklist ]; then
				login=($(find $svrlogs/cphulk/iplist -type f -name "failed-attempt*" -exec ls -lat {} + | grep "$(date +"%F_%H:")" | head -1 | awk '{print $NF}'))

				listed=$(wc -l $login | awk '{print $1}')

				uniqlisted=$(cat $blacklist | grep "Total:" | awk '{print $2}')

				ip_data
			fi
		fi
	fi
}

function ip_data() {
	echo "Login failure count: $count" >>$svrlogs/ipmonitor/loginlog_$time.txt

	echo "Login failure unique IP count: $uniqipcount" >>$svrlogs/ipmonitor/loginlog_$time.txt

	echo "" >>$svrlogs/ipmonitor/loginlog_$time.txt

	echo "New login failure count: $newcount" >>$svrlogs/ipmonitor/loginlog_$time.txt

	echo "New login failure unique IP count: $newuniqip" >>$svrlogs/ipmonitor/loginlog_$time.txt

	echo "" >>$svrlogs/ipmonitor/loginlog_$time.txt

	echo "Login failure count (excluding LK): $listed" >>$svrlogs/ipmonitor/loginlog_$time.txt

	echo "Blacklisted unique IP count: $uniqlisted" >>$svrlogs/ipmonitor/loginlog_$time.txt

	echo "" >>$svrlogs/ipmonitor/loginlog_$time.txt

	cat $login >>$svrlogs/ipmonitor/loginlog_$time.txt
}

login_log

static_ip

mail_check

sort_log

blacklist

summary
