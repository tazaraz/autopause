#!/bin/sh
# 0: Do not restart if stopped. 1: Please do restart if somehow stopped.
RESTART_IF_STOPPED=0

PORT=0
NAME=""
EXECUTE=""

PIDFILE="pause.pid"
BINARY="/usr/bin/screen -DmS ${EXECUTE}"

source "service.cfg"

assert_vars() {
    # Check if the required variables have been set
    FAILED=0

    # Set the binary default value
    if [ "$PORT" -eq 0 ]; then FAILED=1; echo "Variable PORT must be set"; fi
    if [ -z "$NAME" ];    then FAILED=1; echo "Variable NAME must be set"; fi
    if [ -z "$EXECUTE" ]; then FAILED=1; echo "Variable EXECUTE must be set"; fi

    if [ "$FAILED" -eq 1 ]; then exit 1; fi
}

start() {
    assert_vars

    # If the server is not running
    if ! screen -list | grep -q "$NAME"; then
        # The server is paused, kill the waiting process
        if [ -f $PIDFILE ]; then
            kill $(cat $PIDFILE)
            rm $PIDFILE
        fi

        # Start the server
        $BINARY $PARAMETERS &

        # If screen hates us
        if [ $? -ne 0 ]; then
            echo "Server could not start"
            return 1
        fi

        echo "Server started"
        return 0

    # The server is running
    elif ! screen -list | grep -q "$NAME"; then
        echo "Server already running"
        return 1

    # The server is paused, kill the waiting process and restart
    else
        # Killing the pause restarts the server
        echo "Server was paused, restarting"
        kill $(cat $PIDFILE)
        rm $PIDFILE
    fi
}

stop() {
    assert_vars

    # If the server is running
    if screen -list | grep -q "$NAME"; then
        echo "Stopping server"
        $BINARY -p 0 -S $NAME -X eval 'stuff "stop"\015'

    # The server is paused, kill the waiting process
    elif [ -f $PIDFILE ]; then
        kill $(cat $PIDFILE)
        rm $PIDFILE

        # Killing the pause restarts the server, so we need to stop it again
        # This closes the screen session mercilessly, otherwise we need to wait before the server is up again
        screen -p 0 -S $NAME -X quit
    else
        echo "No server running"
        return 1
    fi

    return 0
}

pause(){
    assert_vars

    # If it is the server running
    if screen -list | grep -q "$NAME" ; then
        stop

        # Give the server a moment to stop
        sleep 3

        # Start ncat and save its pid so we can kill it later, for freeing the port
        # Use a & so it runs in the background, releasing the terminal or cron (if thats a thing)
        # Upon a connect, ncat will exit by sending "", after which the server starts
        (echo "" | $(ncat -l $PORT & echo $! > $PIDFILE) > /dev/null; rm $PIDFILE && start) &
    fi

    return 0
}

try_pause(){
    assert_vars

    # If the server is not running and we are note waiting for a new connection
    if [ $RESTART_IF_STOPPED -eq 1 ] && [ ! -f $PIDFILE ] && ! screen -list | grep -q "$NAME"; then
        start
    else
        $BINARY -p 0 -S $NAME -X eval 'stuff "list\015"'

        # The line directly after the /list commond should be an amount, which
        # can only once per instance be 0. This prevents stopping the server when
        # someone, instead of the server, does a /list or says "There are 0"
        online="$(grep -n "There are 0" logs/latest.log | tail -1)"

        # If we did notice no one is online, pause
        if [ "$online" != "" ]; then
            pause
        fi
    fi

    return 0
}

# Change directory to the real location, in case when using a symlink
cd $(dirname $([ -x "$(command -v realpath)" ] && realpath "$0" || readlink -f "$0"))

case "$1" in
start)
        shift
        start "$@" "$PARAMETERS"
        exit $?
        ;;
stop)
        stop
        exit $?
        ;;
pause)
        pause
        exit $?
        ;;
restart)
        shift
        stop && (start "$@" "$PARAMETERS")
        exit $?
        ;;
try_pause)
        shift
        try_pause
        exit $?
        ;;
*)
        echo "Usage: ${0} {start|stop|pause|restart}"
        exit 2
        ;;
esac