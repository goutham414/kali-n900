setenv mmcnum 0
setenv mmcpart 1 
setenv mmctype ext4
setenv bootargs root=/dev/mmcblk0p1 rootwait ro console=tty0 vram=12M ubi.mtd=5
setenv setup_omap_atag
setenv mmckernfile /boot/uImage-4.5.0-rc1+
setenv mmcinitrdfile /boot/uInitrd-4.5.0-rc1+
setenv mmcscriptfile
run trymmckerninitrdboot
