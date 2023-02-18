#!/bin/bash

if [ "$(id -u)" == "0" ]; then
  clear
  # Mac Address
  ifconfig wlo1 down && macchanger -a wlo1
  ifconfig wlo1 up
else
  echo "Execute as root"
fi
