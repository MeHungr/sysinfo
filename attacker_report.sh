#!/bin/bash

# ===== Formatting =====
green=$'\e[32m'
red=$'\e[31m'
bold=$'\e[1m'
reset=$'\e[0m'
# ======================

# Clear screen
clear

# Report message
echo -e "${green}Attacker Report${reset} - "$(date "+%B %d, %Y")""
# Newline
echo

# Look in the file for ips and format the output
printf "${red}${bold}%-8s%-15s%-7s${reset}\n" "COUNT" "IP ADDRESS" "COUNTRY"
while read -r count ip; do
    if [[ count -gt 10 ]]; then
        printf "%-8s%-16s%-7s\n" "$count" "$ip" "$(curl -s ipinfo.io/"$ip"/country)"
    fi
done < <(grep 'Failed password' syslog.log | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort | uniq -c | sort -n)

# Newline
echo
