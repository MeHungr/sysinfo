#!/bin/bash

# ====== ANSI Color codes =====
green="\033[1;32m"
red="\033[31m"
reset="\033[0m"
# =============================

# ===== Formatted strings =====
format="%-25s %s\n"
# =============================

# ===== System variables =====
# This is a lot of parsing man
# Thanks for making me relearn awk
# I had fun with this
hostname="$(hostname)"
domain="$(hostname -d || echo "none")"
defaultif="$(ip route | awk '/default/ { print $5 }')"
ip="$(ip a show "$defaultif" | awk '/inet/ { print $2 }' | head -n 1 | cut -d'/' -f1)"
gateway="$(ip route | awk '/default/ { print $3 }')"
netmask="$(ifconfig | awk -v ip="$ip" '$0 ~ ip { print $4 }')"
nameservers="$(awk '/nameserver ([0-9]{1,3}\.){3}[0-9]{1,3}/ { print $2 }' /etc/resolv.conf)" # Only ipv4
# Source release file rather than parsing :3
. /etc/os-release
kernelver="$(uname -r)"
storage="$(df -h)"
totalstorage="$(awk '/\/$/ { print $2 }' <<< "$storage")"
usedstorage="$(awk '/\/$/ { print $3 }' <<< "$storage")"
availstorage="$(awk '/\/$/ { print $4 }' <<< "$storage")"
cpu="$(awk -F ": " '/model name/ { print $2;exit }' /proc/cpuinfo)"
numofcores="$(awk -F ": " '/cpu cores/ { print $2;exit }' /proc/cpuinfo)"
numofproc="$(nproc)"
raminfo="$(free -h)"
totalram="$(awk '/Mem/ { print $2 }' <<< "$raminfo")"
availram="$(awk '/Mem/ { print $NF }' <<< "$raminfo")"
# ============================

# ===== Log output to log file =====
# This uses process substitution -
# >() creates a named pipe that tee reads from
# and exec writes to. Stderr is then redirected
# to the same place that stdout is going (2>&1).
# exec just tells the program where to point stdout
exec > >(tee ${hostname}_system_report.log) 2>&1
# ==================================

# ===== Device Info =====
print_device_info() {
    printf "${green}Device Information${reset}\n"

    printf "$format" "Hostname:" "$hostname"
    printf "$format" "Domain:" "$domain"
} # =======================

# ===== Network Info =====
print_network_info() {
    printf "${green}Network Information${reset}\n"

    printf "$format" "IP Address:" "$ip"
    printf "$format" "Gateway:" "$gateway"
    printf "$format" "Netmask:" "$netmask"

    # Print all ipv4 nameservers
    count=1
    while IFS= read -r nameserver; do
        printf "$format" "DNS${count}:" "$nameserver"
        ((count++)) # Hate this syntax
    done <<< "$nameservers"
}
# ========================

# ===== OS Info =====
print_os_info() {
    printf "${green}Operating System Information${reset}\n"
    
    printf "$format" "Operating System:" "$PRETTY_NAME"
    printf "$format" "OS Version:" "$VERSION_ID"
    printf "$format" "Kernel Version:" "$kernelver"
}
# ===================

# ===== Storage Info =====
print_storage_info() {
    printf "${green}Storage Information${reset}\n"

    printf "$format" "System Drive Total:" "$totalstorage"
    printf "$format" "System Drive Used:" "$usedstorage"
    printf "$format" "System Drive Free:" "$availstorage"
}
# ========================

# ===== CPU Info =====
print_cpu_info() {
    printf "${green}Processor Information${reset}\n"

    printf "$format" "CPU Model:" "$cpu"
    printf "$format" "Number of processors:" "$numofproc"
    printf "$format" "Number of cores:" "$numofcores"
}
# ====================

# ===== Memory Info =====
print_mem_info() {
    printf "${green}Memory Information${reset}\n"

    printf "$format" "Total RAM:" "$totalram"
    printf "$format" "Available RAM:" "$availram"
}
# =======================

# ===== Main formatting =====
main() {
    # Clear the terminal
    clear

    # Title
    printf "${red}System Report${reset} - $(date)\n\n"

    print_device_info
    echo # Echo newline
    print_network_info
    echo # Echo newline
    print_os_info
    echo # Echo newline
    print_storage_info
    echo # Echo newline
    print_cpu_info
    echo # Echo newline
    print_mem_info
}
# ===========================

main
