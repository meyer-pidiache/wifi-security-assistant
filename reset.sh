#!/bin/bash

if [ "$(id -u)" == "0" ]; then
  interface=$(iw dev | awk '$1=="Interface"{print $2}')
  echo "1/5"
  ip link set $interface down
  echo "2/5" 
  iw $interface set type managed
  echo "3/5"
  systemctl restart wpa_supplicant.service NetworkManager.service dhcpcd.service
  echo "4/5"
  macchanger -r $interface
  macchanger -p $interface 
  ip link set $interface up
  echo "Done!"
else
  echo "Execute the program as root"
fi

