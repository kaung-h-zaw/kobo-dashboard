#!/bin/sh

PATH="/sbin:/bin:/usr/sbin:/usr/bin:/usr/lib:"
export LD_LIBRARY_PATH="/usr/local/Kobo"
export QT_GSTREAMER_PLAYBIN_AUDIOSINK=alsasink
export QT_GSTREAMER_PLAYBIN_AUDIOSINK_DEVICE_PARAMETER=bluealsa:DEV=00:00:00:00:00:00
cd /
unset OLDPWD FBINK_FORCE_ROTA

if [ -e "/etc/init.d/z-nickel-hardware-status" ]; then
    unset LD_LIBRARY_PATH
    /etc/init.d/z-nickel-hardware-status
    sync
    /etc/rc.local
else
    rm -f /tmp/nickel-hardware-status
    mkfifo /tmp/nickel-hardware-status
    sync
    /usr/local/Kobo/hindenburg &
    LIBC_FATAL_STDERR_=1 /usr/local/Kobo/nickel -platform kobo -skipFontLoad &
    [ "${PLATFORM}" != "freescale" ] && udevadm trigger &
fi
exit 0
