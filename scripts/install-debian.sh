#!/usr/bin/env bash
#
# Installs a feeze release tarball plus a minimal XFCE desktop into a Debian
# or Ubuntu VM, so the GUI can be tested somewhere other than a dev machine.
#
# The recorder only writes data while the GUI is running, so a working X
# session is not optional here — that is most of what this script sets up.
#
set -euo pipefail

# Installing lightdm asks which display manager to use. There is nobody to
# answer that during provisioning, so it would hang forever.
export DEBIAN_FRONTEND=noninteractive

: "${FEEZE_VERSION:?not set — check 'release' in config/machines.yml}"
: "${FEEZE_TARGET:?not set — check 'target' for this machine}"

# On GitHub the release tag and the tarball name are the same string, and the
# suffix is the distribution it was built for (Ubuntu_24), not the arch.
FEEZE_NAME="feeze_${FEEZE_VERSION}_${FEEZE_TARGET}"
URL="https://github.com/tokiwa-software/feeze/releases/download/${FEEZE_NAME}/${FEEZE_NAME}.tar.gz"
DIR="/home/vagrant/${FEEZE_NAME}"

echo "=== packages ==="
# Second line of defence against the display-manager prompt.
echo "lightdm shared/default-x-display-manager select lightdm" | debconf-set-selections
apt-get update -qq

# Debian 13 split policykit-1 into polkitd + pkexec; Ubuntu still has the old
# name. Read os-release in a subshell — sourcing it directly would clobber
# NAME, VERSION and friends in this script.
DISTRO_ID="$(. /etc/os-release && echo "$ID")"
case "$DISTRO_ID" in
  ubuntu) POLKIT_PKGS="policykit-1" ;;
  debian) POLKIT_PKGS="polkitd pkexec" ;;
  *)      POLKIT_PKGS="polkitd" ;;
esac

# The X server, video drivers and greeter normally arrive as *recommends* of
# the desktop metapackages. --no-install-recommends drops them, and lightdm
# then dies with "Can't launch X server X -core, not found in path" — hence
# every piece is spelled out below.
apt-get install -y --no-install-recommends \
  openjdk-25-jdk libgc1 curl tar \
  xserver-xorg xserver-xorg-core xinit \
  xserver-xorg-video-vmware xserver-xorg-video-fbdev \
  xfce4 xfce4-session xfce4-terminal \
  lightdm slick-greeter \
  libxrender1 libxtst6 libxi6 \
  $POLKIT_PKGS dbus-x11 accountsservice desktop-file-utils

# Absolute path on purpose: /sbin is not on a normal user's PATH on Debian.
/sbin/ldconfig
if /sbin/ldconfig -p | grep -q 'libgc\.so'; then
  echo "OK: $(/sbin/ldconfig -p | grep 'libgc\.so' | head -1)"
else
  echo "FAIL: libgc not visible to the dynamic linker"
  exit 1
fi

echo "=== autologin ==="
# Ubuntu's lightdm PAM config only skips the password prompt for members of
# this group; without it the log says
#   requirement "user ingroup nopasswdlogin" not met by user "vagrant"
groupadd -f nopasswdlogin
gpasswd -a vagrant nopasswdlogin

# Both settings are load-bearing:
#   user-session    — the box default is "ubuntu", a session that does not
#                     exist here, and lightdm restart-loops looking for it.
#                     Must match a file in /usr/share/xsessions/.
#   greeter-session — lightdm ships no greeter of its own.
#                     Must match a file in /usr/share/xgreeters/.
mkdir -p /etc/lightdm/lightdm.conf.d
cat > /etc/lightdm/lightdm.conf.d/50-autologin.conf <<'EOF'
[Seat:*]
autologin-user=vagrant
autologin-user-timeout=0
user-session=xfce
greeter-session=slick-greeter
EOF

systemctl set-default graphical.target

echo "=== privileges ==="
# The GUI's "start local recorder" button goes through pkexec, not sudo, so
# the sudoers drop-in below does not cover it.
mkdir -p /etc/polkit-1/rules.d
cat > /etc/polkit-1/rules.d/49-feeze.rules <<'EOF'
polkit.addRule(function(action, subject) {
    if (action.id == "org.freedesktop.policykit.exec" &&
        subject.user == "vagrant") {
        return polkit.Result.YES;
    }
});
EOF

# Loading the eBPF program needs root.
echo 'vagrant ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/vagrant
chmod 440 /etc/sudoers.d/vagrant

echo "=== feeze ==="
# Provisioning runs as root, but the release belongs to the vagrant user.
# Skip the download if it is already unpacked so repeated runs stay quick.
if [ ! -d "$DIR" ]; then
  su - vagrant -c "cd \$HOME && curl -fL -o '${FEEZE_NAME}.tar.gz' '${URL}' && tar zxf '${FEEZE_NAME}.tar.gz'"
fi

# bin/feeze checks for libgc by running `ldconfig` with no path, which a
# normal Debian user cannot find — so it claims libgc is missing when it is
# not. Reported upstream; patch it here to keep the VM usable.
# The first expression strips any /sbin/ prefixes already present, so running
# provisioning twice cannot produce /sbin//sbin/ldconfig.
sed -i -e 's#\(/sbin/\)*ldconfig#ldconfig#g' \
       -e 's#(ldconfig -p#(/sbin/ldconfig -p#' "${DIR}/bin/feeze"
grep -n 'ldconfig' "${DIR}/bin/feeze"

# If this does not list xfce.desktop, user-session above points at nothing.
echo "=== available sessions ==="
ls /usr/share/xsessions/ || echo "EMPTY — XFCE is not installed"

echo "=== autostart ==="
# XFCE runs everything in ~/.config/autostart when the session starts.
# bash -lc gives a login shell with a sane PATH; wrapping these in
# xfce4-terminal instead tends to die with exit 127 over quoting.
mkdir -p /home/vagrant/.config/autostart

cat > /home/vagrant/.config/autostart/feeze.desktop <<EOF
[Desktop Entry]
Type=Application
Name=feeze GUI
Exec=bash -lc "${DIR}/bin/feeze"
Terminal=false
EOF

cat > /home/vagrant/.config/autostart/feeze-recorder.desktop <<EOF
[Desktop Entry]
Type=Application
Name=feeze recorder
Exec=bash -lc "sudo ${DIR}/bin/feeze_recorder"
Terminal=false
EOF

# A malformed entry is ignored silently, which is a miserable thing to debug.
desktop-file-validate /home/vagrant/.config/autostart/feeze.desktop || echo "WARN: invalid desktop entry"
desktop-file-validate /home/vagrant/.config/autostart/feeze-recorder.desktop || echo "WARN: invalid desktop entry"

# Files written by root here break the session or the autostart without
# saying why.
chown -R vagrant:vagrant /home/vagrant/.config

echo "install: OK"
