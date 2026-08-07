#!/usr/bin/env bash
#
# Provisioning script: installs the feeze release and a minimal XFCE desktop
# so that the GUI can be tested inside a headless VirtualBox VM.
#
# NOTE: feeze's recorder only writes scheduling data while the GUI is running,
#       so a working X session is a hard requirement for testing this release.
#
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive   # PITFALL: without this, installing
                                        # lightdm opens an interactive dialog
                                        # asking for the default display manager
                                        # and provisioning hangs forever.

NAME="feeze_0.001dev_Ubuntu_24"
# Release tag and tarball filename are IDENTICAL on GitHub, hence one variable.
URL="https://github.com/tokiwa-software/feeze/releases/download/${NAME}/${NAME}.tar.gz"
DIR="/home/vagrant/${NAME}"

echo "=== packages ==="
# Pre-answer the debconf question about the display manager (belt and braces
# in addition to DEBIAN_FRONTEND above).
echo "lightdm shared/default-x-display-manager select lightdm" | debconf-set-selections
apt-get update -qq

# PITFALL: --no-install-recommends is dangerous for a desktop stack. The X
# server, video drivers and the greeter are pulled in via *recommends*, not
# depends. Omitting them makes lightdm fail with
#   "Can't launch X server X -core, not found in path"
# Every package below had to be named explicitly for that reason.
apt-get install -y --no-install-recommends \
  openjdk-25-jdk libgc1 curl tar \
  xserver-xorg xserver-xorg-core xinit \
  xserver-xorg-video-vmware xserver-xorg-video-fbdev \
  xfce4 xfce4-session xfce4-terminal \
  lightdm slick-greeter \
  libxrender1 libxtst6 libxi6

echo "=== autologin ==="
# PITFALL: on Ubuntu, lightdm only allows passwordless login for members of
# the 'nopasswdlogin' group. Without this the log shows
#   pam_succeed_if(lightdm:auth): requirement "user ingroup nopasswdlogin" not met
groupadd -f nopasswdlogin
gpasswd -a vagrant nopasswdlogin


# PITFALL: the box default is user-session=ubuntu, which does not exist here
# (only xfce.desktop is installed) -> "Can't find session 'ubuntu'".
# Must match a file in /usr/share/xsessions/ (without the .desktop suffix).
# PITFALL: lightdm ships no greeter of its own -> "Failed to create greeter
# session". Must match a file in /usr/share/xgreeters/ (without .desktop).
mkdir -p /etc/lightdm/lightdm.conf.d
cat > /etc/lightdm/lightdm.conf.d/50-autologin.conf <<'EOF'
[Seat:*]
autologin-user=vagrant
autologin-user-timeout=0

user-session=xfce

greeter-session=slick-greeter
EOF

systemctl set-default graphical.target

echo "=== feeze ==="
# Skip the download if the directory already exists, so repeated
# `vagrant provision` runs stay fast (the tarball is ~5 MB).
if [ ! -d "$DIR" ]; then
  # Run as 'vagrant': provisioning runs as root, but the release must live in
  # the user's home directory with the right ownership.
  su - vagrant -c "cd \$HOME && curl -fL -o '${NAME}.tar.gz' '${URL}' && tar zxf '${NAME}.tar.gz'"
fi

# The recorder needs root to load its eBPF program.
echo 'vagrant ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/vagrant
chmod 440 /etc/sudoers.d/vagrant

echo "=== available sessions ==="
# Sanity check: this must list xfce.desktop, otherwise user-session above is wrong.
ls /usr/share/xsessions/ || echo "EMPTY — XFCE is not installed"

echo "install: OK"
