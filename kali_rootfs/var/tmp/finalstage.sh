#!/bin/sh
#
# finalstage.sh Script to be run inside Kali chroot
# Distributable under the terms of the GNU GPL version 3.

set -e
set -u

# Generate modules.dep and map files
depmod 4.5.0-rc1+

# Generate an initramfs image
update-initramfs -c -k 4.5.0-rc1+

# Create uImage under /boot
mkimage -A arm -O linux -T kernel -C none -a 80008000 -e 80008000 -n 4.5.0-rc1+ -d /boot/zImage-4.5.0-rc1+ /boot/uImage-4.5.0-rc1+

# Create boot.scr
mkimage -A arm -O linux -T script -C none -a 0 -e 0 -n Kali-N900 -d /boot/u-boot.cmd /boot.scr

# Install non-free packages and System V init
apt-get update
apt-get -y --no-install-recommends install firmware-ti-connectivity sysvinit-core

# Console keyboard set up
wget --no-check-certificate -O /var/tmp/rx51_us.map https://github.com/archlinuxarm-n900/n900-keymaps/raw/master/rx51_us.map
sed -i -e '/^XKBMODEL/ s/".*"/"nokiarx51"/' 	-e '/^XKBLAYOUT/ s/".*"/"us"/' 	-e '/^XKBVARIANT/ s/".*"/""/' 	-e '/^XKBOPTIONS/ s/".*"/""/' /etc/default/keyboard
echo 'KMAP="/etc/console/boottime.kmap.gz"' >> /etc/default/keyboard

# Run interactive commands on boot along with install-keymap which cannot be run under a qemu chroot
cat > /etc/init.d/runonce << EOF2
#!/bin/sh
### BEGIN INIT INFO
# Provides:          runonce
# Required-Start:    \$remote_fs
# Required-Stop:
# X-Start-Before:    console-setup
# Default-Start:     S
# Default-Stop:
# X-Interactive:     true
### END INIT INFO
install-keymap /var/tmp/rx51_us.map

# Set root password
echo "Setting root user password..."
while ! passwd; do
	:
done

# Set unprivileged user password
echo "Setting user user password..."
useradd -c "Kali user" -m -s /bin/bash user
while ! passwd user; do
	:
done

# Reconfigure locales and time zone
dpkg-reconfigure locales
dpkg-reconfigure tzdata

rm /etc/init.d/runonce
update-rc.d runonce remove
EOF2

chmod +x /etc/init.d/runonce
update-rc.d runonce defaults

# X11 keyboard set up
for patch in 0001-RX-51-Symbols-Bind-Escape-to-third-level-Backspace.patch 0002-RX-51-Symbols-Bind-function-keys-to-fourth-level-top.patch 0003-RX-51-Symbols-Bind-PgUp-PgDown-Home-End-to-third-lev.patch 0004-RX-51-Symbols-Bind-less-and-greater-to-fourth-level-.patch 0005-RX-51-Symbols-Bind-volume-keys-as-XF86-raise-and-low.patch 0006-RX-51-Symbols-Bind-bar-to-fourth-level-L.patch 0007-RX-51-Symbols-Bind-tilde-to-fourth-level-C-and-F.patch; do
	wget --no-check-certificate -O /var/tmp/$patch https://github.com/archlinuxarm-n900/xkeyboard-config-n900-git/raw/master/$patch
	patch /usr/share/X11/xkb/symbols/nokia_vndr/rx-51 < /var/tmp/$patch
done
