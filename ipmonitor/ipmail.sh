#!/bin/bash

source /home/rlksvrlogs/scripts/dataset.sh

function send_mail() {
	ipmonitor=($(find $svrlogs/ipmonitor -type f -name "ipmonitor*" -exec ls -lat {} + | grep "$(date +"%F_%H:")" | head -1 | awk '{print $NF}'))

	if [ ! -z $ipmonitor ]; then
		data=$(cat $ipmonitor | grep "failure found" | wc -l)

		if [ $data -ne 5 ]; then
			echo "SUBJECT: IP Monitor Log - $(hostname) - $(date +"%F %T")" >>$svrlogs/mail/ipmail_$time.txt
			echo "FROM: IP Monitor <root@$(hostname)>" >>$svrlogs/mail/ipmail_$time.txt
			echo "" >>$svrlogs/mail/ipmail_$time.txt
			echo "$(cat $ipmonitor)" >>$svrlogs/mail/ipmail_$time.txt
			sendmail "$emailmo,$emailmg" <$svrlogs/mail/ipmail_$time.txt
		fi
	fi
}

send_mail
