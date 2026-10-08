#!/bin/sh

set -eu

ARCH=$(uname -m)

echo "Installing package dependencies..."
echo "---------------------------------------------------------------"
# pacman -Syu --noconfirm PACKAGESHERE

echo "Installing debloated packages..."
echo "---------------------------------------------------------------"
get-debloated-pkgs --add-common --prefer-nano

# Comment this out if you need an AUR package
#make-aur-package PACKAGENAME
(
  git clone https://github.com/fastrizwaan/WineZGUI.git
  cd ./WineZGUI
  TAG=$(git tag --sort=-v:refname | grep -vi 'rc\|alpha\|beta' | head -1)
  git checkout "$TAG"
  echo "${TAG#v}" > ~/version
  sudo ./setup --install
)
