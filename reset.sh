#!/bin/bash

if [ "$(id -u)" == "0" ]; then
  echo "1/5"
  ip link set wlo1 down
  echo "2/5" 
  iw wlo1 set type managed
  echo "3/5"
  ip link set wlo1 up
  echo "4/5"
  systemctl restart NetworkManager.service
  echo "5/5"
  macchanger -r wlo1
  macchanger -p wlo1
  sleep 1
  macchanger -p wlo1
  echo "Done!"
else
  echo "Execute the program as root"
fi

