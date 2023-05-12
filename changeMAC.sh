#!/bin/bash

if [ "$(id -u)" == "0" ]; then
  clear
  interface=$(iw dev | awk '$1=="Interface"{print $2}')
  # Mac Address
  ifconfig $interface down && macchanger -a $interface
  ifconfig $Interface up
else
  echo "[*] Execute as root"
fi

