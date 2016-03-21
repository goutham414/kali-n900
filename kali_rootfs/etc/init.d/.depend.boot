TARGETS = mountkernfs.sh fake-hwclock hostname.sh udev keyboard-setup.sh mountdevsubfs.sh hwclock.sh mountall.sh mountall-bootclean.sh mountnfs.sh mountnfs-bootclean.sh x11-common networking urandom checkroot.sh checkfs.sh checkroot-bootclean.sh bootmisc.sh procps kmod runonce
INTERACTIVE = udev keyboard-setup.sh checkroot.sh checkfs.sh runonce
udev: mountkernfs.sh
keyboard-setup.sh: mountkernfs.sh udev
mountdevsubfs.sh: mountkernfs.sh udev
hwclock.sh: mountdevsubfs.sh
mountall.sh: checkfs.sh checkroot-bootclean.sh
mountall-bootclean.sh: mountall.sh
mountnfs.sh: mountall.sh mountall-bootclean.sh networking
mountnfs-bootclean.sh: mountall.sh mountall-bootclean.sh mountnfs.sh
x11-common: mountall.sh mountall-bootclean.sh mountnfs.sh mountnfs-bootclean.sh
networking: mountkernfs.sh mountall.sh mountall-bootclean.sh urandom procps
urandom: mountall.sh mountall-bootclean.sh hwclock.sh
checkroot.sh: fake-hwclock hwclock.sh mountdevsubfs.sh hostname.sh keyboard-setup.sh
checkfs.sh: checkroot.sh
checkroot-bootclean.sh: checkroot.sh
bootmisc.sh: mountnfs-bootclean.sh mountall-bootclean.sh checkroot-bootclean.sh mountall.sh mountnfs.sh udev
procps: mountkernfs.sh mountall.sh mountall-bootclean.sh udev
kmod: checkroot.sh
runonce: mountall.sh mountall-bootclean.sh mountnfs.sh mountnfs-bootclean.sh
