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
                                                                                                  
function dependencies(){
	clear; dependencies=(aircrack-ng macchanger)

	echo -e "${yellowColour}[*]${endColour}${grayColour} Checking programs...${endColour}"
	sleep 2

	for program in "${dependencies[@]}"; do
		echo -ne "\n${yellowColour}[*]${endColour}${blueColour} Tools ${endColour}${purpleColour} $program${endColour}${blueColour}...${endColour}"

		test -f /usr/bin/$program

		if [ "$(echo $?)" == "0" ]; then
			echo -e " ${greenColour}(V)${endColour}"
		else
			echo -e " ${redColour}(X)${endColour}\n"
			echo -e "${yellowColour}[*]${endColour}${grayColour} Installing ${endColour}${blueColour}$program${endColour}${yellowColour}...${endColour}"
			apt-get install $program -y > /dev/null 2>&1
		fi; sleep 1
	done
}

if [ "$(id -u)" == "0" ]; then
  clear
  # Mac Address
  ifconfig wlo1 down && macchanger -a wlo1
  ifconfig wlo1 up
 
  iw dev | grep monitor >/dev/null
  if [[ $(echo $?) -ne 0 ]]; then
    echo "Setting up environment..."
    # Monitor Mode
    airmon-ng check kill
    airmon-ng start wlo1
  fi
  clear
  # New configurations
  macchanger -s wlo1
  iw dev
  sleep 2
  # Networks
  airodump-ng wlo1
else
  echo "Run as root"
fi
