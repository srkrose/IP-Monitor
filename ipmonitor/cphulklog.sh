#!/bin/bash

source /home/sample/scripts/dataset.sh

function cphulk_log() {
	cat /usr/local/cpanel/logs/cphulkd.log | grep -ie "$(date -d '1 hour ago' +"%F %H:")" | awk -F'[= ]' '{for (i=0;i<NF;i++) {for (j=0;j<NF;j++) {for (k=0;k<NF;k++) {if ($i=="[Service]" && $j=="[Remote" && $(j+1)=="IP" && $k=="[Username]") print $1,$2,$(i+1),$(j+3),$(k+1)}}}}' | sed 's/[][]//g' | awk '{printf "%-19s %-17s %-21s %-22s %-50s\n","DATE: "$1,"TIME: "$2,"SERVICE: "$3,"IP: "$4,"USER: "$NF}' | sort | uniq -c >>$temp/cphulklog_$time.txt
}

function static_ip() {
	if [ -r $temp/cphulklog_$time.txt ] && [ -s $temp/cphulklog_$time.txt ]; then
		staticip=($(cat $scripts/ipmonitor/staticip.txt))
		scount=${#staticip[@]}

		iplist=$(cat $temp/cphulklog_$time.txt | awk '{print $9}' | sort | uniq)

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
			data=$(cat $temp/cphulklog_$time.txt | grep ${ips[i]})

			whois=$(sh $scripts/ipmonitor/iplookup.sh ${ips[i]})

			while IFS= read -r line; do
				printf "%-140s %-10s\n" "$line" "ID: $whois" >>$temp/failed-cphulk_$time.txt
			done <<<"$data"
		fi
	done
}

function mail_check() {
	if [ -r $temp/failed-cphulk_$time.txt ] && [ -s $temp/failed-cphulk_$time.txt ]; then
		while IFS= read -r line || [[ -n "$line" ]]; do
			email=$(echo "$line" | awk '{print $11}')

			if [[ $email == *[@]* ]]; then
				domain=$(echo "$email" | awk -F'@' '{print $2}')
				username=$(whmapi1 getdomainowner domain=$domain | grep -i "user:" | awk '{print $2}')

				if [[ "$username" != "~" ]]; then
					status=$(uapi --user=$username Mailboxes get_mailbox_status_list account=$email | grep -i "status:" | awk '{print $2}')

					if [ "$status" -eq 0 ]; then
						echo "$line" >>$temp/cptemp-block_$time.txt
					fi
				else
					echo "$line" >>$temp/cptemp-block_$time.txt
				fi
			else
				echo "$line" >>$temp/cptemp-block_$time.txt
			fi

		done <"$temp/failed-cphulk_$time.txt"
	fi
}

function sort_log() {
	if [ -r $temp/cptemp-block_$time.txt ] && [ -s $temp/cptemp-block_$time.txt ]; then
		sortlog=$(cat $temp/cptemp-block_$time.txt | awk '{for (i=0;i<NF;i++) {if($i=="ID:" && $(i+1)!="") print}}' | sort -k11)

		if [[ ! -z $sortlog ]]; then
			echo "$sortlog" >>$svrlogs/cphulk/iplist/cptemp-block_$time.txt
		fi
	fi
}

function blacklist() {
	if [ -r $svrlogs/cphulk/iplist/cptemp-block_$time.txt ] && [ -s $svrlogs/cphulk/iplist/cptemp-block_$time.txt ]; then
		sh $scripts/cphulk/ipblacklist.sh cptemp-block
	fi
}

function summary() {
	cphulklog=($(find $temp -type f -name "cphulklog*" -exec ls -lat {} + | grep "$(date +"%F_%H:")" | head -1 | awk '{print $NF}'))

	if [ ! -z $cphulklog ]; then
		count=$(wc -l $cphulklog | awk '{print $1}')

		uniqipcount=$(cat $cphulklog | awk '{print $9}' | sort | uniq | wc -l)

		failedcphulk=($(find $temp -type f -name "failed-cphulk*" -exec ls -lat {} + | grep "$(date +"%F_%H:")" | head -1 | awk '{print $NF}'))

		if [ ! -z $failedcphulk ]; then
			newcount=$(wc -l $failedcphulk | awk '{print $1}')

			newuniqip=$(cat $failedcphulk | awk '{print $9}' | sort | uniq | wc -l)

			blacklist=($(find $svrlogs/cphulk/block -type f -name "cphulkip-blacklisted*" -exec ls -lat {} + | grep "$(date +"%F_%H:")" | head -1 | awk '{print $NF}'))

			if [ ! -z $blacklist ]; then
				login=($(find $svrlogs/cphulk/iplist -type f -name "cptemp-block*" -exec ls -lat {} + | grep "$(date +"%F_%H:")" | head -1 | awk '{print $NF}'))

				listed=$(wc -l $login | awk '{print $1}')

				uniqlisted=$(cat $blacklist | grep "Total:" | awk '{print $2}')

				ip_data
			fi
		fi
	fi
}

function ip_data() {
	echo "cPHulk login failure count: $count" >>$svrlogs/ipmonitor/cphulklog_$time.txt

	echo "cPHulk login failure unique IP count: $uniqipcount" >>$svrlogs/ipmonitor/cphulklog_$time.txt

	echo "" >>$svrlogs/ipmonitor/cphulklog_$time.txt

	echo "cPHulk new login failure count: $newcount" >>$svrlogs/ipmonitor/cphulklog_$time.txt

	echo "cPHulk new login failure unique IP count: $newuniqip" >>$svrlogs/ipmonitor/cphulklog_$time.txt

	echo "" >>$svrlogs/ipmonitor/cphulklog_$time.txt

	echo "cPHulk login failure count (excluding LK): $listed" >>$svrlogs/ipmonitor/cphulklog_$time.txt

	echo "Blacklisted unique IP count: $uniqlisted" >>$svrlogs/ipmonitor/cphulklog_$time.txt

	echo "" >>$svrlogs/ipmonitor/cphulklog_$time.txt

	cat $login >>$svrlogs/ipmonitor/cphulklog_$time.txt
}

cphulk_log

static_ip

mail_check

sort_log

blacklist

summary
