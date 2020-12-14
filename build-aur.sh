#!/bin/bash
set -e
set -u

mkdir -p /tmp/aur
cd /tmp/aur
git clone "https://aur.archlinux.org/$1.git"
cd "$1"
source ./PKGBUILD && pacman -Syu --noconfirm --needed --asdeps "${makedepends[@]}" "${depends[@]}"
paccache -r
chown -R user .
su user -c "makepkg -c"
pwd
ls
