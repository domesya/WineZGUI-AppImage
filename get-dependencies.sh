#!/bin/sh

set -eu

ARCH=$(uname -m)

echo "Installing package dependencies..."
echo "---------------------------------------------------------------"
pacman -Syu --noconfirm git

echo "Installing debloated packages..."
echo "---------------------------------------------------------------"
get-debloated-pkgs --add-common --prefer-nano

# Comment this out if you need an AUR package
make-aur-package zenity-rs-bin

git clone https://github.com/fastrizwaan/WineZGUI.git
cd ./WineZGUI
sudo ./setup --install ;
git rev-parse --short HEAD > ~/version
