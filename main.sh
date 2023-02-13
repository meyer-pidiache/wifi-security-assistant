#!/bin/bash

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
