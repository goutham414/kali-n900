#!/bin/sh
### BEGIN INIT INFO
# Provides:          console-setup.sh
# Required-Start:    $remote_fs
# Required-Stop:
# Should-Start:      console-screen kbd
# Default-Start:     2 3 4 5
# Default-Stop:
# X-Interactive:     true
# Short-Description: Set console font and keymap
### END INIT INFO

do_configure=no
if [ -f /bin/setupcon ]; then
    case "$1" in
        stop|status)
        # console-setup isn't a daemon
        ;;
        start|force-reload|restart|reload)
            case "`uname 2>/dev/null`" in
            *FreeBSD*)
                do_configure=yes
                ;;
            *) # assuming Linux with udev

                # Skip only the first time (i.e. when the system boots)
                [ ! -f /run/console-setup/boot_completed ] || do_configure=yes
                mkdir -p /run/console-setup
                > /run/console-setup/boot_completed

                [ /etc/console-setup/cached_setup_terminal.sh \
                      -nt /etc/default/keyboard ] || do_configure=yes
                [ /etc/console-setup/cached_setup_terminal.sh \
                      -nt /etc/default/console-setup ] || do_configure=yes
                ;;
            esac
	    ;;
        *)
            echo 'Usage: /etc/init.d/console-setup {start|reload|restart|force-reload|stop|status}'
            exit 3
            ;;
    esac
fi

if [ "$do_configure" = yes ]; then
    if [ -f /lib/lsb/init-functions ]; then
        . /lib/lsb/init-functions
    else
        log_action_begin_msg () {
	    echo -n "$@... "
        }

        log_action_end_msg () {
	    if [ "$1" -eq 0 ]; then
	        echo done.
	    else
	        echo failed.
	    fi
        }
    fi

    if [ -f /etc/default/locale ]; then
        # In order to permit auto-detection of the charmap when
        # console-setup-mini operates without configuration file.
        . /etc/default/locale
        export LANG
    fi
    log_action_begin_msg "Setting up console font and keymap"
    if setupcon --save; then
        log_action_end_msg 0
    else
        log_action_end_msg $?
    fi
fi
