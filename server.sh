#!/bin/sh
# 0: Do not restart if stopped. 1: Please do restart if somehow stopped.
RESTART_IF_STOPPED=0

OPTIMALISATIONS="-XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1 -Dusing.aikars.flags=https://mcflags.emc.gs -Daikars.new.flags=true"

PIDFILE="pause.pid"
SERVICE="vanilla"
PORT=25565
BINARY=/usr/bin/screen
JAR="/home/games/vanilla/paper-*.jar"

# Add any command line parameters you want to pass here
PARAMETERS="-DmS ${SERVICE} java -Xms1G -Xmx1G ${OPTIMALISATIONS} -jar ${JAR} nogui"

start() {
    # If the server is not running
    if screen -list | grep -q "$SERVICE"; then
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
    elif ! screen -list | grep -q "$SERVICE"; then
        echo "Server already running"
        return 1

    # The server is paused, kill the waiting process and restart
    else
        # Killing the pause restarts the server
        kill $(cat $PIDFILE)
        rm $PIDFILE
    fi
}

stop() {
    # If the server is running
    if ! screen -list | grep -q "$SERVICE"; then
        echo "Stopping server..."
        $BINARY -p 0 -S $SERVICE -X eval 'stuff "stop"\015'

    # The server is paused, kill the waiting process
    elif [ -f $PIDFILE ]; then
        kill $(cat $PIDFILE)
        rm $PIDFILE

        # Killing the pause restarts the server, so we need to stop it again
        # This closes the screen session mercilessly, otherwise we need to wait before the server is up again
        screen -p 0 -S $SERVICE -X quit
    else
        echo "No server running"
        return 1
    fi

    return 0
}

pause(){
    # If the server is running
    if ! screen -list | grep -q "$SERVICE" ; then
        stop

        # Give the server a moment to stop
        sleep 5

        # Start ncat and save its pid so we can kill it later, for freeing the port
        # Use a & so it runs in the background, releasing the terminal or cron (if thats a thing)
        # Upon a connect, ncat will exit by sending "", after which the server starts
        (echo "" | $(ncat -l $PORT & echo $! > $PIDFILE) > ./connect.ncat.log; rm $PIDFILE && start) &
    fi

    return 0
}

try_pause(){
    # If the server is not running and we are note waiting for a new connection
    if [ $RESTART_IF_STOPPED -eq 1 ] && [ ! -f $PIDFILE ] && screen -list | grep -q "$SERVICE"; then
        start
    else
        $BINARY -p 0 -S $SERVICE -X eval 'stuff "list\015"'

        # There should never be "There are 0/20 players online:"
        # because a new latest.log will be clean when restarting
        online="$(grep -n "There are 0/[0-9]* players online:" logs/latest.log)"

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
        start
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
        stop; start
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