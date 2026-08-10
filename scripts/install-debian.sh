#!/usr/bin/env bash
#
# Provisioning script: installs the feeze release and a minimal XFCE desktop
# so that the GUI can be tested inside a headless VirtualBox VM.
#
#
set -euo pipefail



export DEBIAN_FRONTEND=noninteractive   # PITFALL: without this, installing
                                        # lightdm opens an interactive dialog
                                        # asking for the default display manager
                                        # and provisioning hangs forever.

: "${FEEZE_VERSION:?not set — check 'release' in config/machines.yml}"
: "${FEEZE_TARGET:?not set — check 'target' for this machine}"

FEEZE_NAME="feeze_${FEEZE_VERSION}_${FEEZE_TARGET}"
URL="https://github.com/tokiwa-software/feeze/releases/download/${FEEZE_NAME}/${FEEZE_NAME}.tar.gz"
DIR="/home/vagrant/${FEEZE_NAME}"

echo "=== packages ==="
# Pre-answer the debconf question about the display manager (belt and braces
# in addition to DEBIAN_FRONTEND above).
echo "lightdm shared/default-x-display-manager select lightdm" | debconf-set-selections
apt-get update -qq

# PITFALL: /etc/os-release defines NAME, VERSION, ID... — sourcing it directly
# overwrites same-named shell variables. Read only what we need, in a subshell.
DISTRO_ID="$(. /etc/os-release && echo "$ID")"
case "$DISTRO_ID" in
  ubuntu) POLKIT_PKGS="policykit-1" ;;
  debian) POLKIT_PKGS="polkitd pkexec" ;;
  *)      POLKIT_PKGS="polkitd" ;;
esac



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
  libxrender1 libxtst6 libxi6 \
  $POLKIT_PKGS dbus-x11 accountsservice

# PITFALL: on Debian /sbin is not in a normal user's PATH, so a bare
# `ldconfig` fails with "command not found" even though the tool exists.
# Use the absolute path.
/sbin/ldconfig

if /sbin/ldconfig -p | grep -q 'libgc\.so'; then
  echo "OK: $(/sbin/ldconfig -p | grep 'libgc\.so' | head -1)"
else
  echo "FAIL: libgc not visible to the dynamic linker"
  exit 1
fi
echo "=== PATH workaround ==="
# WORKAROUND: bin/feeze calls `ldconfig` without an absolute path (line ~87 of
# the release script). On Debian /sbin is not in a normal user's PATH, so the
# check fails and feeze wrongly reports "libgc.so not installed" although
# libgc1 is installed. Ubuntu happens to have /sbin in PATH, hence Debian-only.
# Fix upstream: use /sbin/ldconfig. Until then, put /sbin on PATH everywhere.
cat > /etc/profile.d/sbin-path.sh <<'EOF'
export PATH="/usr/sbin:/sbin:$PATH"
EOF
chmod 644 /etc/profile.d/sbin-path.sh

# /etc/profile.d is only read by *login* shells; xfce4-terminal starts a
# non-login interactive shell, so add it to .bashrc as well.
su - vagrant -c 'grep -qxF '\''export PATH="/usr/sbin:/sbin:$PATH"'\'' ~/.bashrc || echo '\''export PATH="/usr/sbin:/sbin:$PATH"'\'' >> ~/.bashrc'
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

# GUI's "start local recorder" button uses pkexec (PolicyKit), NOT sudo,
# so /etc/sudoers.d/vagrant does not help here.
mkdir -p /etc/polkit-1/rules.d
cat > /etc/polkit-1/rules.d/49-feeze.rules <<'EOF'
polkit.addRule(function(action, subject) {
    if (action.id == "org.freedesktop.policykit.exec" &&
        subject.user == "vagrant") {
        return polkit.Result.YES;
    }
});
EOF

echo "=== feeze ==="
# Skip the download if the directory already exists, so repeated
# `vagrant provision` runs stay fast (the tarball is ~5 MB).
if [ ! -d "$DIR" ]; then
  # Run as 'vagrant': provisioning runs as root, but the release must live in
  # the user's home directory with the right ownership.
  su - vagrant -c "cd \$HOME && curl -fL -o '${FEEZE_NAME}.tar.gz' '${URL}' && tar zxf '${FEEZE_NAME}.tar.gz'"
fi

# WORKAROUND: patch the release script directly — it calls `ldconfig` without
# an absolute path, which fails on Debian where /sbin is not in the user's PATH.
# Reported upstream; this keeps the VM usable meanwhile.
sed -i -e 's#/sbin/ldconfig#ldconfig#g' -e 's#(ldconfig -p#(/sbin/ldconfig -p#' "${DIR}/bin/feeze"
grep -n 'ldconfig' "${DIR}/bin/feeze"
# The recorder needs root to load its eBPF program.
echo 'vagrant ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/vagrant
chmod 440 /etc/sudoers.d/vagrant

echo "=== available sessions ==="
# Sanity check: this must list xfce.desktop, otherwise user-session above is wrong.
ls /usr/share/xsessions/ || echo "EMPTY — XFCE is not installed"

echo "=== feeze autostart ==="
# XFCE runs everything in ~/.config/autostart on session start.
# The GUI must run first: the recorder only records while the GUI is up.
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
Exec=xfce4-terminal --title=recorder --hold --command="sudo ${DIR}/bin/feeze_recorder"
Terminal=false
EOF

# PITFALL: files created by root in the user's home break the session or the
# autostart silently. Fix ownership explicitly.
chown -R vagrant:vagrant /home/vagrant/.config

echo "install: OK"
