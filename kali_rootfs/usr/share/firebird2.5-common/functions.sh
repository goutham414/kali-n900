# Shell functions library used by firebird2.5-{super,classic}.postinst
# This file needs to be sourced

if [ -z "${FB_VER:-}" ];
then
    echo Please define FB_VER before sourcing functions.sh
    exit 1
fi

if [ -z "${FB_FLAVOUR:-}" ];
then
    echo Please define FB_FLAVOUR before sourcing functions.sh
    exit 1
fi

export FB_VER
FB_VER_no_dots=`echo $FB_VER | sed -e 's/\.//g'`

FB="/usr/lib/firebird/$FB_VER"
VAR="/var/lib/firebird/$FB_VER"
ETC="/etc/firebird/$FB_VER"
LOG_DIR="/var/log/firebird"
LOG="$LOG_DIR/firebird${FB_VER}.log"
RUN="/var/run/firebird/$FB_VER"
DEFAULT="/etc/default/firebird${FB_VER}"
DBAPasswordFile="$ETC/SYSDBA.password"

create_var_run_firebird()
{
    if ! [ -d $RUN ]; then
        mkdir --parent $RUN
        chmod 0770 $RUN
        chown firebird:firebird $RUN
    fi
}

fixPerms()
{
    create_var_run_firebird

    find $VAR -type d -exec chown firebird:firebird {} \; \
                           -exec chmod 0770 {} \;
    find $VAR -type f -exec chown firebird:firebird {} \; \
                           -exec chmod 0660 {} \;

    chmod 0770 $LOG_DIR
    chown firebird:firebird $LOG_DIR
}

checkFirebirdAccount() {
    getent passwd firebird > /dev/null \
        || adduser --system --quiet --home /var/lib/firebird \
            --group --gecos "Firebird Database Administator" firebird
}

#---------------------------------------------------------------------------
# set new SYSDBA password with gsec

writeNewPassword () {
    local NewPasswd=$1

    # Provide default SYSDBA.password
    if [ ! -e "$DBAPasswordFile" ];
    then
        touch "$DBAPasswordFile"
        chmod 0600 $DBAPasswordFile

        cat <<_EOF > "$DBAPasswordFile"
# Password for firebird SYSDBA user
#
# You may want to use the following commands for changing it:
#   dpkg-reconfigure firebird${FB_VER}-super
# or
#   dpkg-reconfigure firebird${FB_VER}-classic
#
# If you change the password manually with gsec, please update it here too.
# Keeping this file in sync with the security database is critical for the
# correct functioning of the init.d script and for the ability to change the
# password via \`dpkg-reconfigure firebird${FB_VER}-super/classic\'

ISC_USER=sysdba
ISC_PASSWORD=masterkey
_EOF
        ISC_PASSWORD=masterkey
    else
        . $DBAPasswordFile
    fi
    if [ "$NewPasswd" != "${ISC_PASSWORD:-}" ]; then
        export ISC_PASSWORD
        ERR=
        gsec -user sysdba <<EOF || ERR=1
modify sysdba -pw $NewPasswd
EOF

        # Running as root may create lock files that
        # need to be owned by firebird instead
        fixPerms

        if [ -n "$ERR" ]; then
            echo "Error setting new SYSDBA password"
            echo "Please reconfigure the firebird package to try again"
            return
        fi

        if grep "^ *ISC_PASSWORD=" $DBAPasswordFile > /dev/null;
        then
            # Update existing line

            # create .tmp file preserving permissions
            cp -a "$DBAPasswordFile" "$DBAPasswordFile.tmp"

            sed -e "s/^ *ISC_PASSWORD=.*/ISC_PASSWORD=\"$NewPassword\"/" \
            < "$DBAPasswordFile" > "$DBAPasswordFile.tmp"
            mv -f "$DBAPasswordFile.tmp" "$DBAPasswordFile"
        else
            # Add new line
            echo "ISC_PASSWORD=$NewPassword" >> $DBAPasswordFile
        fi

        ISC_PASSWORD=$NewPassword
    fi
}

firebird_server_enabled()
{
    QUESTION=shared/firebird/enabled
    db_get $QUESTION || true

    if [ "${RET:-}" = true ]; then
        return 0    # enabled
    else
        return 1    # disabled
    fi
}

enable_firebird_server()
{
    sed -i -e 's/^ *ENABLE_FIREBIRD_SERVER=.*/ENABLE_FIREBIRD_SERVER=yes/' $DEFAULT
    grep -q 'ENABLE_FIREBIRD_SERVER=yes' $DEFAULT || echo 'ENABLE_FIREBIRD_SERVER=yes' >> $DEFAULT
    call_initd firebird${FB_VER}-$FB_FLAVOUR start || return $?
    if [ "$FB_FLAVOUR" = 'classic' ]; then
        update-inetd --enable gds_db
    fi
}

disable_firebird_server()
{
    if [ "$FB_FLAVOUR" = 'classic' ]; then
        update-inetd --disable gds_db
    else
        call_initd firebird${FB_VER}-$FB_FLAVOUR stop
    fi
    sed -i -e 's/^ *ENABLE_FIREBIRD_SERVER=.*/ENABLE_FIREBIRD_SERVER=no/' $DEFAULT
    grep -q 'ENABLE_FIREBIRD_SERVER=no' $DEFAULT || echo 'ENABLE_FIREBIRD_SERVER=no' >> $DEFAULT
}

askForDBAPassword ()
{
    if [ -f $DBAPasswordFile ];
    then
        . $DBAPasswordFile
    fi

    QUESTION=shared/firebird/sysdba_password/new_password

    db_get "$QUESTION" || true
    if [ -z "$RET" ];
    then
        if [ -z "${ISC_PASSWORD:-}" ];
        then
            NewPassword=`cut -c 1-8 /proc/sys/kernel/random/uuid`
        else
            NewPassword=$ISC_PASSWORD
        fi
    else
        NewPassword=$RET
    fi

    writeNewPassword $NewPassword

    # Make debconf forget the password
    db_reset $QUESTION || true
}


#-----------------------------------------------------------------------
# update inetd service entry 
# Check to see if we have xinetd installed or plain inetd. Install differs
# for each of them

updateInetdServiceEntry() {

    update-inetd --add \
      "localhost:gds_db\t\tstream\ttcp\tnowait\tfirebird\t/usr/sbin/tcpd\t/usr/sbin/fb_inet_server"

    # No need to reload inetd, since update-inetd already reloads it
}

call_initd()
{
    script=$1
    action=$2

    if [ -f "/etc/init.d/$script" ];
    then
        if [ -x "`which invoke-rc.d 2>/dev/null`" ];
        then
            invoke-rc.d --disclose-deny $script $action
        else
            /etc/init.d/$script $action
        fi
    fi
}

#---------------------------------------------------------------------------
# stop super server if it is running
# Also will only stop firebird, since that has the init script
# (firebird1.0.x deb has it)

stopServerIfRunning()
{

    # We conflict with previous firebid2-*-server packages
    # therefore there is no need to stop them

    #call_initd_script firebird stop
    #call_initd_script firebird2 stop
    call_initd_script "firebird$FB_VER" stop
}


#---------------------------------------------------------------------------
# stop server if it is running 

checkIfServerRunning() {

    stopServerIfRunning || exit $?

    ### These below are commented due to two reasons:
    ### 1) to avoid pre-dependency on procps
    ### 2) stopServerIfRunning (init.d script actually) must exit with
    ###    an error in case it was unable to stop the server anyway
    ### Classic installs are allowed to continue running whatever they're
    ### running until client disconnects
    ### What happend when new fb_inet_server works with previous fb_lock_mgr?
    ### We hope for the best, that's what.

#    # check if server is being actively used.
#    checkString=`ps -efww| egrep "(fbserver|fbguard)" |grep -v grep`
#    
#    if [ ! -z "$checkString" ]; then
#        echo "An instance of the Firebird Super server seems to be running."
#        echo "(the fbserver or fbguard process was detected running on your system)"
#        echo "Please quit all Firebird applications and then proceed"
#        exit 1
#    fi
#    
#    
#    checkString=`ps -efww| egrep "(fb_inet_server|gds_pipe)" |grep -v grep`
#    
#    if [ ! -z "$checkString" ]; then
#	echo "An instance of the Firebird classic server seems to be running."
#	echo "(the fb_inet_server or gds_pipe process was detected running on your system)"
#	echo "Please quit all Firebird applications and then proceed"
#	exit 1
#    fi
#	
#    # the following check for running interbase or firebird 1.0 servers.
#    checkString=`ps -efww| egrep "(ibserver|ibguard)" |grep -v grep`
#    
#    if [ ! -z "$checkString" ]; then
#	echo "An instance of the Firebird/InterBase Super server seems to be running."
#	echo "(the ibserver or ibguard process was detected running on your system)"
#	echo "Please quit all Firebird applications and then proceed"
#	exit 1
#    fi
#
#
#    checkString=`ps -efww| egrep "(ib_inet_server|gds_pipe)" |grep -v grep`
#    
#    if [ ! -z "$checkString" ]; then
#	echo "An instance of the Firebird/InterBase classic server seems to be running."
#	echo "(the fb_inet_server or gds_pipe process was detected running on your system)"
#	echo "Please quit all Firebird applications and then proceed"
#	exit 1
#    fi
#

    # stop lock manager if it is the only thing running.
#    for i in `ps -efww | egrep "[gds|fb]_lock_mgr" awk '{print $2}' ` 
#    do
#	kill $i
#    done

}

instantiate_security_db()
{
    SYS_DIR="$VAR/system"
    DEF_SEC_DB="$SYS_DIR/default-security2.fdb"
    SEC_DB="$SYS_DIR/security2.fdb"

    if ! [ -e "$SEC_DB" ];
    then
        install -o firebird -g firebird -m 0660 "$DEF_SEC_DB" "$SEC_DB"

        # Since we've copied the default security database, the SYSDBA password
        # must be reset
        if [ -f "$DBAPasswordFile" ]; then
            rm "$DBAPasswordFile"
        fi
        echo Created default security2.fdb
    fi
}

firebird_config_postinst()
{
    instantiate_security_db

    fixPerms

    if firebird_server_enabled; then
        if enable_firebird_server; then
            askForDBAPassword
        else
            echo "Error starting firebird server"
            echo "Please fix the error and reconfigure the package"
            echo "if you want to change the SYSDBA password"
        fi
    else
        disable_firebird_server
    fi

    debhelper_hook configure
}

# vi: set sw=4 ts=8 filetype=sh sts=4 :
