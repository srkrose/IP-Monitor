#!/bin/bash

source /home/sample/scripts/dataset.sh

input=$1

function ip_lookup() {

	whois=$(curl https://ipapi.co/$input/country/)

	if ! [[ "$whois" =~ ^[A-Z]{2}$ ]]; then
		whois=$(curl ipinfo.io/$input/country/)

		if ! [[ "$whois" =~ ^[A-Z]{2}$ ]]; then
			whois=$(curl ip-api.com/line/$input?fields=countryCode)

			if ! [[ "$whois" =~ ^[A-Z]{2}$ ]]; then
				whois=$(curl ipwho.is/$input?fields=country_code | sed 's/}//;s/"//g' | awk -F':' '{print $NF}')

				if ! [[ "$whois" =~ ^[A-Z]{2}$ ]]; then
					whois=""
				fi
			fi
		fi
	fi

	echo "$whois"
}

ip_lookup
