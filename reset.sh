#!/bin/bash

if [ "$(id -u)" == "0" ]; then
  interface=$(iw dev | awk '$1=="Interface"{print $2}')
  echo "[*] Managed Interface"
  ip link set $interface down && iw $interface set type managed
  echo "[*] Restarting Network Services"
  systemctl restart wpa_supplicant.service NetworkManager.service dhcpcd.service
  echo -e "[*] Set default MAC\n"
  macchanger -p $interface 
  ip link set $interface up
  echo -e "\n[*] Done!"
else
  echo "[*] Execute the program as root"
fi

