# WI-FI Tool

WI-FI Deauthentication Attack.

Based on: 

- S4vitar - https://github.com/s4vitar/wifiCrack

- David Bombal - https://www.youtube.com/watch?v=WfYxrLaqlN8

## Requirements

### [Aircrack-ng](https://www.aircrack-ng.org/doku.php?id=install_aircrack#installing_aircrack-ng_from_source)

``` bash
# Aircrack-ng requirements
sudo apt-get update
sudo apt-get install autoconf automake libtool shtool pkg-config libssl-dev ethtool rfkill libnl-3-dev libnl-genl-3-dev build-essential libstdc++-11-dev
# Aircrack-ng
wget -O - https://download.aircrack-ng.org/aircrack-ng-1.7.tar.gz | tar -xz
cd aircrack-ng-1.7 && autoreconf -i
./configure --with-experimental
make
make install
ldconfig
cd .. && rm -rf aircrack-ng-1.7
```

## main.sh

Start program.

``` bash
sudo ./main.sh
```
