#!/usr/bin/env bash
# This file is part of the Feeze scheduling analysis tool.
#
# This code is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License, version 3,
# as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License, version 3,
# along with this program.  If not, see <http://www.gnu.org/licenses/>


# -----------------------------------------------------------------------
#
#  Copyright (c) 2025, Tokiwa Software GmbH, Germany
#
#  Source of install-fedora.sh
#
#  Provisioning of a Fedora test machine
#
#
# -----------------------------------------------------------------------

# Provisioning script for Fedora: installs the feeze release and a minimal
# XFCE desktop so that the GUI can be tested inside a VirtualBox VM.
#
set -euo pipefail

: "${FEEZE_VERSION:?not set — check 'release' in config/machines.yml}"
: "${FEEZE_TARGET:?not set — check 'target' for this machine}"

FEEZE_NAME="feeze_${FEEZE_VERSION}_${FEEZE_TARGET}"
URL="https://github.com/tokiwa-software/feeze/releases/download/${FEEZE_NAME}/${FEEZE_NAME}.tar.gz"
DIR="/home/vagrant/${FEEZE_NAME}"
FILES="/tmp/feeze-files"

echo "=== packages ==="
# NOTE: Fedora 43 (Server Edition) has no xfce group in its metadata, so the
# desktop packages are named individually. Package names differ from Debian:
#   libgc1 -> gc, openjdk-25-jdk -> java-25-openjdk, policykit-1 -> polkit
dnf -y install \
  java-25-openjdk gc curl tar \
  xorg-x11-server-Xorg xorg-x11-xinit \
  xfwm4 xfce4-session xfce4-panel xfdesktop xfce4-terminal xfce4-settings \
  lightdm slick-greeter \
  polkit dbus-x11 accountsservice desktop-file-utils

echo "=== libgc check ==="
/sbin/ldconfig
if /sbin/ldconfig -p | grep -q 'libgc\.so'; then
  echo "OK: $(/sbin/ldconfig -p | grep 'libgc\.so' | head -1)"
else
  echo "FAIL: libgc not visible to the dynamic linker"
  exit 1
fi

echo "=== available sessions / greeters ==="
ls /usr/share/xsessions/ || echo "EMPTY — no session installed"
ls /usr/share/xgreeters/ || echo "EMPTY — no greeter installed"

echo "=== autologin ==="
# NOTE: unlike Debian/Ubuntu, Fedora's lightdm PAM config does not use a
# 'nopasswdlogin' group — autologin works from lightdm.conf alone.
mkdir -p /etc/lightdm/lightdm.conf.d
install -m 644 "$FILES/lightdm-autologin.conf" /etc/lightdm/lightdm.conf.d/50-autologin.conf

systemctl set-default graphical.target
systemctl enable lightdm

echo "=== polkit ==="
# The GUI's "start local recorder" button uses pkexec (PolicyKit), not sudo.
mkdir -p /etc/polkit-1/rules.d
install -m 644 "$FILES/49-feeze.rules" /etc/polkit-1/rules.d/49-feeze.rules

# The recorder needs root to load its eBPF program.
echo 'vagrant ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/vagrant
chmod 440 /etc/sudoers.d/vagrant

echo "=== feeze ==="
if [ ! -d "$DIR" ]; then
  su - vagrant -c "cd \$HOME && curl -fL -o '${FEEZE_NAME}.tar.gz' '${URL}' && tar zxf '${FEEZE_NAME}.tar.gz'"
fi

echo "=== feeze autostart ==="
mkdir -p /home/vagrant/.config/autostart
for f in feeze feeze-recorder; do
  sed "s#@FEEZE_DIR@#${DIR}#g" "$FILES/$f.desktop.tmpl" \
    > "/home/vagrant/.config/autostart/$f.desktop"
done

desktop-file-validate /home/vagrant/.config/autostart/feeze.desktop || echo "WARN: invalid desktop entry"
desktop-file-validate /home/vagrant/.config/autostart/feeze-recorder.desktop || echo "WARN: invalid desktop entry"
chown -R vagrant:vagrant /home/vagrant/.config

echo "install: OK"
