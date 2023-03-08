#!/bin/bash

#Colours
greenColour="\e[0;32m\033[1m"
endColour="\033[0m\e[0m"
redColour="\e[0;31m\033[1m"
blueColour="\e[0;34m\033[1m"
yellowColour="\e[0;33m\033[1m"
purpleColour="\e[0;35m\033[1m"
turquoiseColour="\e[0;36m\033[1m"
grayColour="\e[0;37m\033[1m"

function checkDependencies() {
  clear
  dependencies=(aircrack-ng macchanger xterm)

  echo -e "${yellowColour}[*]${endColour}${grayColour} Checking programs...${endColour}"
  sleep 2

  for program in "${dependencies[@]}"; do
    echo -ne "\n${yellowColour}[*]${endColour}${blueColour} Tools ${endColour}${purpleColour} $program${endColour}${blueColour}...${endColour}"

    if [ -x "$(command -v $program)" ]; then
      echo -e " ${greenColour}(V)${endColour}"
    else
      echo -e " ${redColour}(X)${endColour}\n"
      if [ "$program" == "aircrack-ng" ]; then
        echo "Please install aircrack-ng"
        exit 0
      else
        echo -e "${yellowColour}[*]${endColour}${grayColour} Installing ${endColour}${blueColour}$program${endColour}${yellowColour}...${endColour}"
        apt-get install $program -y
      fi
    fi
    sleep 1
  done
  clear
}

if [ "$(id -u)" == "0" ]; then
  clear
  checkDependencies

  # Mac Address
  interface=$(iw dev | awk '$1=="Interface"{print $2}')
  ifconfig $interface down && macchanger -a $interface
  ifconfig $interface up

  iw dev | grep monitor >/dev/null
  if [[ $(echo $?) -ne 0 ]]; then
    echo "Setting up environment..."
    # Monitor Mode
    airmon-ng check kill
    airmon-ng start $interface
  fi
  clear

  # Show new configurations
  macchanger -s $interface
  iw dev
  sleep 2

  # Show networks
  xterm -e "airodump-ng $interface"
else
  echo "Run as root"
fi
