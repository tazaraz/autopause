#!/bin/sh
PIDFILE="pause.pid"
SERVICE="minecraft"
BINARY=/usr/bin/screen
PARAMETERS="-DmS ${SERVICE} java -Xms1G -Xmx5G -jar /home/games/minecraft/forge.jar nogui"
# add any command line parameters you want to pass here

start() {
    # If the server is not running
    if ! screen -list | grep -q "$SERVICE"; then
        # The server is paused, kill the waiting process
        if [ -f $PIDFILE ]; then
            kill $(cat $PIDFILE)
            rm $PIDFILE
        fi

        # Start the server
        $BINARY $PARAMETERS &

        # If screen hates us
        if [ $? -ne 0 ]; then
            echo "Minecraft server could not start"
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
    if screen -list | grep -q "$SERVICE"; then
        echo "Stopping Minecraft Server"
        $BINARY -p 0 -S $SERVICE -X eval 'stuff "save-all"\015'
        $BINARY -p 0 -S $SERVICE -X eval 'stuff "stop"\015'
        rm $PIDFILE

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
    # If it is the server running
    if screen -list | grep -q "$SERVICE" ; then
        stop

        # Give the server a moment to stop
        sleep 10

        # Start ncat and save its pid so we can kill it later, for freeing the port
        # Use a & so it runs in the background, releasing the terminal or cron (if thats a thing)
        # Upon a connect, ncat will exit by sending "", after which the server starts
        (echo "" | $(ncat -l 25565 & echo $! > $PIDFILE) > /dev/null && rm $PIDFILE && start) &
    fi

    return 0
}

try_stop(){
    $BINARY -p 0 -S $SERVICE -X eval 'stuff "list\015"'

    # There should never be "There are 0/20 players online:"
    # because a new latest.log will be clean when restarting
    online="$(grep -n "There are 0/20 players online:" logs/latest.log)"

    # If we did notice no one is online, pause
    if [ $online = "" ]; then
        pause
    fi

    return 0
}

# Change directory to the scripts location, prevents a bug when using as service
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