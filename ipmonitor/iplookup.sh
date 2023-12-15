#!/bin/bash

source /home/sample/scripts/dataset.sh

input=$1

function ip_lookup() {

	whois=$(curl https://ipapi.co/$input/country/)
	error=$(echo "$whois" | grep "error")

	if [[ ! -z $error ]]; then
		whois=$(curl ipinfo.io/$input/country/)
		error=$(echo "$whois" | grep "error")

		if [[ ! -z $error ]]; then
			whois=$(curl ip-api.com/line/$input?fields=countryCode)
			error=$(echo "$whois" | grep "error")

			if [[ ! -z $error ]]; then
				whois=$(curl ipwho.is/$input?fields=country_code | sed 's/}//;s/"//g' | awk -F':' '{print $NF}')
			fi
		fi
	fi

	echo "$whois"
}

ip_lookup
