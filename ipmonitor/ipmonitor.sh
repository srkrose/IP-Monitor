#!/bin/bash

source /home/sample/scripts/dataset.sh

function check_directory() {
	sh $scripts/directory.sh
}

printf "IP Monitor Log - $(date +"%F %T")\n" >>$svrlogs/ipmonitor/ipmonitor_$time.txt

printf "\n************************************************************\n" >>$svrlogs/ipmonitor/ipmonitor_$time.txt

function loginfail_log() {
	printf "\n# *** Login Log - Failed ***\n\n" >>$svrlogs/ipmonitor/ipmonitor_$time.txt

	sh $scripts/ipmonitor/loginfail.sh

	loginfail=($(find $svrlogs/ipmonitor -type f -name "loginlog*" -exec ls -lat {} + | grep "$(date +"%F_%H:")" | head -1 | awk '{print $NF}'))

	if [[ ! -z $loginfail ]]; then
		echo "$(cat $loginfail)" >>$svrlogs/ipmonitor/ipmonitor_$time.txt
	else
		printf "No login failure found\n" >>$svrlogs/ipmonitor/ipmonitor_$time.txt
	fi

	printf "\n************************************************************\n" >>$svrlogs/ipmonitor/ipmonitor_$time.txt
}

function ftpd_log() {
	printf "\n# *** FTPD Log ***\n\n" >>$svrlogs/ipmonitor/ipmonitor_$time.txt

	sh $scripts/ipmonitor/ftpdlog.sh

	ftpdlog=($(find $svrlogs/ipmonitor -type f -name "ftpdlog*" -exec ls -lat {} + | grep "$(date +"%F_%H:")" | head -1 | awk '{print $NF}'))

	if [[ ! -z $ftpdlog ]]; then
		echo "$(cat $ftpdlog)" >>$svrlogs/ipmonitor/ipmonitor_$time.txt
	else
		printf "No ftpd failure found\n" >>$svrlogs/ipmonitor/ipmonitor_$time.txt
	fi

	printf "\n************************************************************\n" >>$svrlogs/ipmonitor/ipmonitor_$time.txt
}

function ssh_log() {
	printf "\n# *** SSH Log ***\n\n" >>$svrlogs/ipmonitor/ipmonitor_$time.txt

	sh $scripts/ipmonitor/sshlog.sh

	sshlog=($(find $svrlogs/ipmonitor -type f -name "sshlog*" -exec ls -lat {} + | grep "$(date +"%F_%H:")" | head -1 | awk '{print $NF}'))

	if [[ ! -z $sshlog ]]; then
		echo "$(cat $sshlog)" >>$svrlogs/ipmonitor/ipmonitor_$time.txt
	else
		printf "No ssh failure found\n" >>$svrlogs/ipmonitor/ipmonitor_$time.txt
	fi

	printf "\n************************************************************\n" >>$svrlogs/ipmonitor/ipmonitor_$time.txt
}

function exim_dovecot() {
	printf "\n# *** Exim Log - Dovecot Login ***\n\n" >>$svrlogs/ipmonitor/ipmonitor_$time.txt

	sh $scripts/ipmonitor/eximdovecot.sh

	eximdovecot=($(find $svrlogs/ipmonitor -type f -name "eximdovecot*" -exec ls -lat {} + | grep "$(date +"%F_%H:")" | head -1 | awk '{print $NF}'))

	if [[ ! -z $eximdovecot ]]; then
		echo "$(cat $eximdovecot)" >>$svrlogs/ipmonitor/ipmonitor_$time.txt
	else
		printf "No dovecot login failure found\n" >>$svrlogs/ipmonitor/ipmonitor_$time.txt
	fi

	printf "\n************************************************************\n" >>$svrlogs/ipmonitor/ipmonitor_$time.txt
}

function exim_smtphost() {
	printf "\n# *** Exim Log - SMTP Login ***\n\n" >>$svrlogs/ipmonitor/ipmonitor_$time.txt

	sh $scripts/ipmonitor/eximsmtphost.sh

	eximsmtphost=($(find $svrlogs/ipmonitor -type f -name "eximsmtphost*" -exec ls -lat {} + | grep "$(date +"%F_%H:")" | head -1 | awk '{print $NF}'))

	if [[ ! -z $eximsmtphost ]]; then
		echo "$(cat $eximsmtphost)" >>$svrlogs/ipmonitor/ipmonitor_$time.txt
	else
		printf "No SMTP login failure found\n" >>$svrlogs/ipmonitor/ipmonitor_$time.txt
	fi

	printf "\n************************************************************\n" >>$svrlogs/ipmonitor/ipmonitor_$time.txt
}

function mail_log() {
	printf "\n# *** Mail Log ***\n\n" >>$svrlogs/ipmonitor/ipmonitor_$time.txt

	sh $scripts/ipmonitor/maillog.sh

	maillog=($(find $svrlogs/ipmonitor -type f -name "maillog*" -exec ls -lat {} + | grep "$(date +"%F_%H:")" | head -1 | awk '{print $NF}'))

	if [[ ! -z $maillog ]]; then
		echo "$(cat $maillog)" >>$svrlogs/ipmonitor/ipmonitor_$time.txt
	else
		printf "No imap/pop3 failure found\n" >>$svrlogs/ipmonitor/ipmonitor_$time.txt
	fi

	printf "\n************************************************************\n" >>$svrlogs/ipmonitor/ipmonitor_$time.txt
}

function cphulk_log() {
	printf "\n# *** cPHulk Log ***\n\n" >>$svrlogs/ipmonitor/ipmonitor_$time.txt

	sh $scripts/ipmonitor/cphulklog.sh

	cphulklog=($(find $svrlogs/ipmonitor -type f -name "cphulklog*" -exec ls -lat {} + | grep "$(date +"%F_%H:")" | head -1 | awk '{print $NF}'))

	if [[ ! -z $cphulklog ]]; then
		echo "$(cat $cphulklog)" >>$svrlogs/ipmonitor/ipmonitor_$time.txt
	else
		printf "No cPHulk failure found\n" >>$svrlogs/ipmonitor/ipmonitor_$time.txt
	fi

	printf "\n************************************************************\n" >>$svrlogs/ipmonitor/ipmonitor_$time.txt
}

function send_mail() {
	sh $scripts/ipmonitor/ipmail.sh
}

check_directory

loginfail_log

ftpd_log

ssh_log

exim_dovecot

exim_smtphost

mail_log

cphulk_log

#send_mail
