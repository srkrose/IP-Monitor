#!/bin/bash

source /home/sample/scripts/dataset.sh

function rmvblacklist_auto() {
	type_array=("fake-mail" "failed-ftpd" "failed-ssh" "failed-dovecot" "failed-smtphost" "failed-attempt" "cptemp-block")

	for type in ${type_array[@]}; do
		blacklistold=($(find $svrlogs/cphulk/iplist -mtime 14 -type f -name "$type*"))

		if [ ! -z $blacklistold ]; then
			len=${#blacklistold[@]}

			for ((i = 0; i < len; i++)); do
				username=$(echo "${blacklistold[i]}" | awk -F'/' '{print $NF}' | awk -F'_' '{print $1}')

				ips=($(cat ${blacklistold[i]} | awk '{for (i=0;i<NF;i++) {if($i=="IP:") print $(i+1)}}' | sort | uniq))

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
		fi
	done
}

rmvblacklist_auto
