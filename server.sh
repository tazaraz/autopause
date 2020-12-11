#!/bin/sh
# Copyright (c) 2019 TeamSpeak Systems GmbH
# Altered to own use
# All rights reserved

PIDFILE="server.pid"
SERVICE="minecraft"
BINARY=/usr/bin/screen
PARAMETERS="-DmS ${SERVICE} java -Xms1G -Xmx5G -jar /home/games/minecraft/forge.jar nogui"
# add any command line parameters you want to pass here

start() {
    # No server running at all
    if [ ! -f $PIDFILE ]; then
        echo "Server running" > $PIDFILE
        $BINARY $PARAMETERS &

        if [ $? -ne 0 ]; then
            echo "Minecraft server could not start"
            return 4
        fi

        echo "Server started"

    # The server is running
    elif [ $(cat $PIDFILE) = "Server running" ]; then
        echo "Server already running"

    # The server is paused, kill the waiting process and restart
    else
        kill $(cat $PIDFILE)
        rm $PIDFILE
        start()
    fi
}

stop() {
    # There is something active
    if [ -f $PIDFILE ]; then
        # The server is running
        if [ $(cat $PIDFILE) = "Server running" ]; then
            echo -n "Stopping Minecraft Server"
            $BINARY -p 0 -S $SERVICE -X eval 'stuff "save-all"\015'
            $BINARY -p 0 -S $SERVICE -X eval 'stuff "stop"\015'
            rm $PIDFILE

        # The server is paused, kill the waiting process
        else
            kill $(cat $PIDFILE)
        fi
    else
        echo "No server running"
    fi
    return 0
}

pause(){
    # Stop the server
    stop()
    # Upon a connect, ncat will exit by sending "", after which the server starts
    echo "" | ncat -l 25565 && rm $PIDFILE && start() &

    # We move the previous command to the background
    # and save the pid of the whole command
    echo $! > $PIDFILE
}

try_stop(){
    $BINARY -p 0 -S $SERVICE -X eval 'stuff "list\015"'

    # There should never be "There are 0/20 players online:" because a new latest.log should be generated every time on start
    online="$(grep -n "There are 0/20 players online:" logs/latest.log)"

    if [ $online = "" ]; then
        pause()
    fi
}

# change directory to the scripts location
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
*)
        echo "Usage: ${0} {start|stop|pause|restart}"
        exit 2
        ;;
esac