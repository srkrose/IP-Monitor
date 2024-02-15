#!/bin/bash

source /home/sample/scripts/dataset.sh

function mail_log() {
	cat /var/log/maillog | grep -ie "$(if (($(date -d '1 hour ago' +"%-d") < 10)); then date -d '1 hour ago' +"%b  %-d %H:"; else date -d '1 hour ago' +"%b %d %H:"; fi)" | grep -ie "dovecot:" | grep -ie "imap-login:\|pop3-login:" | grep -ie "auth failed" | grep -iv "Inactivity\|user=<>" | awk '{for(i=1;i<=NF;i++) {for(j=1;j<=NF;j++) {if($i~/user=/ && $j~/rip=/) {print $1,$2,$3,$6,$j,$i}}}}' | sed 's/dovecot//;s/user//;s/rip//;s/=//g;s/,//g;s/<//;s/>//' | awk '{gsub(/:/,"",$4)}1' | awk '{printf "%-15s %-17s %-19s %-22s %-50s\n","DATE: "$1" "$2,"TIME: "$3, "TYPE: "$4,"IP: "$5,"USER: "$NF}' | sort | uniq -c >>$temp/maillog_$time.txt
}

function static_ip() {
	if [ -r $temp/maillog_$time.txt ] && [ -s $temp/maillog_$time.txt ]; then
		staticip=($(cat $scripts/ipmonitor/staticip.txt))
		scount=${#staticip[@]}

		iplist=$(cat $temp/maillog_$time.txt | awk '{print $10}' | sort | uniq)

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
			data=$(cat $temp/maillog_$time.txt | grep ${ips[i]})

			whois=$(sh $scripts/ipmonitor/iplookup.sh ${ips[i]})

			while IFS= read -r line; do
				printf "%-130s %-10s\n" "$line" "ID: $whois" >>$temp/failed-mail_$time.txt
			done <<<"$data"
		fi
	done
}

function mail_check() {
	if [ -r $temp/failed-mail_$time.txt ] && [ -s $temp/failed-mail_$time.txt ]; then
		while IFS= read -r line || [[ -n "$line" ]]; do
			email=$(echo "$line" | awk '{print $10}')

			if [[ $email == *[@]* ]]; then
				domain=$(echo "$email" | awk -F'@' '{print $2}')
				username=$(whmapi1 getdomainowner domain=$domain | grep -i "user:" | awk '{print $2}')

				if [[ "$username" != "~" ]]; then
					status=$(uapi --user=$username Mailboxes get_mailbox_status_list account=$email | grep -i "status:" | awk '{print $2}')

					if [ "$status" -eq 0 ]; then
						echo "$line" >>$temp/fake-mail_$time.txt
					fi
				else
					echo "$line" >>$temp/fake-mail_$time.txt
				fi
			else
				echo "$line" >>$temp/fake-mail_$time.txt
			fi

		done <"$temp/failed-mail_$time.txt"
	fi
}

function sort_log() {
	if [ -r $temp/fake-mail_$time.txt ] && [ -s $temp/fake-mail_$time.txt ]; then
		sortlog=$(cat $temp/fake-mail_$time.txt | awk '{for (i=0;i<NF;i++) {if($i=="ID:" && $(i+1)!="") print}}' | sort -k10)

		if [[ ! -z $sortlog ]]; then
			echo "$sortlog" >>$svrlogs/cphulk/iplist/fake-mail_$time.txt
		fi
	fi
}

function blacklist() {
	if [ -r $svrlogs/cphulk/iplist/fake-mail_$time.txt ] && [ -s $svrlogs/cphulk/iplist/fake-mail_$time.txt ]; then
		sh $scripts/cphulk/ipblacklist.sh fake-mail
	fi
}

function summary() {
	maillog=($(find $temp -type f -name "maillog*" -exec ls -lat {} + | grep "$(date +"%F_%H:")" | head -1 | awk '{print $NF}'))

	if [ ! -z $maillog ]; then
		count=$(wc -l $maillog | awk '{print $1}')

		uniqipcount=$(cat $maillog | awk '{print $10}' | sort | uniq | wc -l)

		failedmail=($(find $temp -type f -name "failed-mail*" -exec ls -lat {} + | grep "$(date +"%F_%H:")" | head -1 | awk '{print $NF}'))

		if [ ! -z $failedmail ]; then
			newcount=$(wc -l $failedmail | awk '{print $1}')

			newuniqip=$(cat $failedmail | awk '{print $10}' | sort | uniq | wc -l)

			blacklist=($(find $svrlogs/cphulk/block -type f -name "mailip-blacklisted*" -exec ls -lat {} + | grep "$(date +"%F_%H:")" | head -1 | awk '{print $NF}'))

			if [ ! -z $blacklist ]; then
				login=($(find $svrlogs/cphulk/iplist -type f -name "fake-mail*" -exec ls -lat {} + | grep "$(date +"%F_%H:")" | head -1 | awk '{print $NF}'))

				listed=$(wc -l $login | awk '{print $1}')

				uniqlisted=$(cat $blacklist | grep "Total:" | awk '{print $2}')

				ip_data
			fi
		fi
	fi
}

function ip_data() {
	echo "IMAP/POP3 login failure count: $count" >>$svrlogs/ipmonitor/maillog_$time.txt

	echo "IMAP/POP3 login failure unique IP count: $uniqipcount" >>$svrlogs/ipmonitor/maillog_$time.txt

	echo "" >>$svrlogs/ipmonitor/maillog_$time.txt

	echo "IMAP/POP3 new login failure count: $newcount" >>$svrlogs/ipmonitor/maillog_$time.txt

	echo "IMAP/POP3 new login failure unique IP count: $newuniqip" >>$svrlogs/ipmonitor/maillog_$time.txt

	echo "" >>$svrlogs/ipmonitor/maillog_$time.txt

	echo "IMAP/POP3 fake login failure count: $listed" >>$svrlogs/ipmonitor/maillog_$time.txt

	echo "Blacklisted unique IP count: $uniqlisted" >>$svrlogs/ipmonitor/maillog_$time.txt

	echo "" >>$svrlogs/ipmonitor/maillog_$time.txt

	cat $login >>$svrlogs/ipmonitor/maillog_$time.txt
}

mail_log

static_ip

mail_check

sort_log

blacklist

summary
