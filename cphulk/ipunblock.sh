#!/bin/bash

source /home/sample/scripts/dataset.sh

ipv4='^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'
ipv6='^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}$'

input=$1

function check_ip() {
    if [[ $input =~ $ipv4 || $input =~ $ipv6 ]]; then
        ip=$input

        ip_unblock
    else
        echo "IP not valid"
    fi
}

function ip_unblock() {
    search=$(whmapi1 read_cphulk_records list_name='black' | grep "$ip")

    if [[ ! -z $search ]]; then
        result1=$(whmapi1 delete_cphulk_record list_name='black' ip=$ip | grep -i "result:" | awk '{print $2}')

        result2=$(whmapi1 flush_cphulk_login_history_for_ips ip=$ip | grep -i "result:" | awk '{print $2}')

        if [[ "$result1" -eq 1 && "$result2" -eq 1 ]]; then
            echo "$(date +"%F %T") unblocked $ip" >>$svrlogs/cphulk/ipunblock_$logtime.txt

            echo "IP unblocked"
        else
            echo "IP cannot unblock"
        fi

        reason=$(egrep "$ip" $svrlogs/cphulk/iplist/*)

        echo "Reason:"
        echo "$reason"

        add_ip
    else
        echo "No record found in IP blacklist"
    fi
}

function add_ip() {
    read -p "Add to Static IP list (y/n)? " answer

    if [[ $answer == "y" || $answer == "Y" ]]; then
        echo "$ip" >>$scripts/ipmonitor/staticip.txt

        echo "$ip IP added to Static IP list successfully"
    fi
}

check_ip
