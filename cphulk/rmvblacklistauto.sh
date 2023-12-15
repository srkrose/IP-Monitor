#!/bin/bash

source /home/sample/scripts/dataset.sh

function rmvblacklist_auto() {
	for ((i = 0; i < len; i++)); do
		username=$(echo "${blacklistold[i]}" | awk -F'/' '{print $NF}' | awk -F'_' '{print $1}')

		if [[ $username == "failed-dovecot" || $username == "failed-smtphost" ]]; then
			ips=($(cat ${blacklistold[i]} | awk '{print $5}' | sort | uniq))

		elif [[ $username == "failed-ftpd" ]]; then
			ips=($(cat ${blacklistold[i]} | awk '{print $6}' | sort | uniq))

		elif [[ $username == "failed-ssh" ]]; then
			ips=($(cat ${blacklistold[i]} | awk '{print $7}' | sort | uniq))

		elif [[ $username == "fake-mail" ]]; then
			ips=($(cat ${blacklistold[i]} | awk '{print $8}' | sort | uniq))

		elif [[ $username == "failed-attempt" || $username == "cptemp-block" ]]; then
			ips=($(cat ${blacklistold[i]} | awk '{print $9}' | sort | uniq))

		fi

		ipcount=${#ips[@]}

		num=0

		for ((j = 0; j < ipcount; j++)); do
			search=$(whmapi1 read_cphulk_records list_name='black' | grep ${ips[j]})

			if [[ ! -z $search ]]; then
				result=$(whmapi1 delete_cphulk_record list_name='black' ip=${ips[j]} | grep -i "result:" | awk '{print $2}')
				num=$((num + 1))

				if [ "$result" -eq 1 ]; then
					echo "$num - Removed: ${ips[j]}" >>$svrlogs/cphulk/unblock/$username-rmvblacklistauto_$time.txt
				else
					echo "$num - Failed: ${ips[j]}" >>$svrlogs/cphulk/unblock/$username-rmvblacklistauto_$time.txt
				fi
			fi
		done

		echo "Total: $num" >>$svrlogs/cphulk/unblock/$username-rmvblacklistauto_$time.txt
		echo "" >>$svrlogs/cphulk/unblock/$username-rmvblacklistauto_$time.txt
	done
}

function dovecot_blacklist() {
	blacklistold=($(find $svrlogs/cphulk/iplist -mtime 14 -type f -name "failed-dovecot*"))

	if [ ! -z $blacklistold ]; then
		len=${#blacklistold[@]}
		rmvblacklist_auto
	fi
}

function smtphost_blacklist() {
	blacklistold=($(find $svrlogs/cphulk/iplist -mtime 14 -type f -name "failed-smtphost*"))

	if [ ! -z $blacklistold ]; then
		len=${#blacklistold[@]}
		rmvblacklist_auto
	fi
}

function ftpd_blacklist() {
	blacklistold=($(find $svrlogs/cphulk/iplist -mtime 14 -type f -name "failed-ftpd*"))

	if [ ! -z $blacklistold ]; then
		len=${#blacklistold[@]}
		rmvblacklist_auto
	fi
}

function ssh_blacklist() {
	blacklistold=($(find $svrlogs/cphulk/iplist -mtime 14 -type f -name "failed-ssh*"))

	if [ ! -z $blacklistold ]; then
		len=${#blacklistold[@]}
		rmvblacklist_auto
	fi
}

function mail_blacklist() {
	blacklistold=($(find $svrlogs/cphulk/iplist -mtime 14 -type f -name "fake-mail*"))

	if [ ! -z $blacklistold ]; then
		len=${#blacklistold[@]}
		rmvblacklist_auto
	fi
}

function login_blacklist() {
	blacklistold=($(find $svrlogs/cphulk/iplist -mtime 14 -type f -name "failed-attempt*"))

	if [ ! -z $blacklistold ]; then
		len=${#blacklistold[@]}
		rmvblacklist_auto
	fi
}

function cphulk_blacklist() {
	blacklistold=($(find $svrlogs/cphulk/iplist -mtime 14 -type f -name "cptemp-block*"))

	if [ ! -z $blacklistold ]; then
		len=${#blacklistold[@]}
		rmvblacklist_auto
	fi
}

mail_blacklist

ftpd_blacklist

ssh_blacklist

dovecot_blacklist

smtphost_blacklist

login_blacklist

cphulk_blacklist
