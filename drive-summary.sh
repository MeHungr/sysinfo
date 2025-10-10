#!/bin/bash

# ====== ANSI Colors ======
bold=$'\033[1m'
reset=$'\033[0m'
green=$'\033[1;32m'
yellow=$'\033[1;33m'
red=$'\033[1;31m'
blue=$'\033[1;34m'
cyan=$'\033[1;36m'
magenta=$'\033[1;35m'
gray=$'\033[0;90m'
# =========================

# Safe print function that ignores color escape codes when padding
color_printf() {
  local format="$1"
  shift
  # Strip ANSI codes for padding width
  local clean_args=()
  for arg in "$@"; do
    clean_args+=("$(sed -E 's/\x1B\[[0-9;]*[A-Za-z]//g' <<<"$arg")")
  done
  printf "$format" "${clean_args[@]}" | awk -v ORS="" '{printf "%s", $0}'
}

# ===== Header =====
printf "${bold}${cyan}%-30s %-8s %-8s %-8s %-8s${reset}\n" \
  "Drive" "Size" "Used" "Avail" "Usage"
printf "${gray}%0.s-${reset}" {1..75}; echo

# ===== Totals =====
total_used=0
total_avail=0
total_size=0

for disk in $(lsblk -dno NAME | grep -Ev '^(loop|zram|ram)'); do
  disk_size=$(lsblk -b -dn -o SIZE /dev/$disk)
  total_size=$((total_size + disk_size))
  disk_size_hr=$(numfmt --to=iec <<< "$disk_size")
  drive_model=$(lsblk -dno MODEL "/dev/$disk")
  [ -z "$drive_model" ] && drive_model="$disk"

  used=0
  avail=0

  partitions=$(lsblk -ln -o NAME,TYPE /dev/$disk | awk '$2 == "part" {print $1}')
  for part in $partitions; do
    if lsblk -no FSTYPE "/dev/$part" | grep -qw swap; then
      continue
    fi

    mountpoint=$(findmnt -n -o TARGET "/dev/$part")
    if [ -n "$mountpoint" ]; then
      df_out=$(df -B1 --output=used,avail "/dev/$part" | tail -1)
      part_used=$(awk '{print $1}' <<< "$df_out")
      part_avail=$(awk '{print $2}' <<< "$df_out")
      used=$((used + part_used))
      avail=$((avail + part_avail))
    fi
  done

  sum=$((used + avail))
  usage_pct=0
  [ "$sum" -gt 0 ] && usage_pct=$((used * 100 / sum))

  if (( usage_pct < 60 )); then
    usage_color=$green
  elif (( usage_pct < 85 )); then
    usage_color=$yellow
  else
    usage_color=$red
  fi

  total_used=$((total_used + used))
  total_avail=$((total_avail + avail))

  # Use color_printf for width-correct columns
  color_printf "%-30s %-8s %-8s %-8s " \
    "${bold}${drive_model}${reset}" \
    "$disk_size_hr" \
    "$(numfmt --to=iec <<< $used)" \
    "$(numfmt --to=iec <<< $avail)"
  printf "${usage_color}%-8s${reset}\n" "${usage_pct}%"
done

total_sum=$((total_used + total_avail))
total_pct=0
[ "$total_sum" -gt 0 ] && total_pct=$((total_used * 100 / total_sum))

printf "${gray}%0.s-${reset}" {1..75}; echo
color_printf "${bold}${magenta}%-30s${reset} %-8s %-8s %-8s " \
  "TOTAL" \
  "$(numfmt --to=iec <<< $total_size)" \
  "$(numfmt --to=iec <<< $total_used)" \
  "$(numfmt --to=iec <<< $total_avail)"
printf "${bold}${cyan}%-8s${reset}\n" "${total_pct}%"
echo

