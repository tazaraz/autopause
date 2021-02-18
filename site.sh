BINARY="npx nodemon"
PARAMETERS="server.js > log/node.log 2>&1 &"
COMMANDLINE_PARAMETERS="" #add any command line parameters you want to pass here
PIDFILE=server.pid

start() {
    # If the server is running
    if [ -e $PIDFILE ]; then
        if (ps -p "$(cat "$PIDFILE")" >/dev/null 2>&1); then
                echo "The server is already running, try restart or stop."
                return 1
        else
                echo "$PIDFILE found, but no server running. Please view the logfile for details."
                rm $PIDFILE
        fi
    fi

    echo "Starting node.js server"
    rm -f log/node.log
    $BINARY $PARAMETERS

    echo $! > $PIDFILE
    if [ $? -ne 0 ]; then
            echo "Server started, for details please view the log file"
    else
            echo "Server could not start"
            return 4
    fi
}

stop() {
    if [ ! -e $PIDFILE ]; then
        echo "No server running ($PIDFILE is missing)"
        return 0
    fi
    PID=$(cat "$PIDFILE")
    if (! ps -p "$PID" >/dev/null 2>&1); then
        echo "No server running"
        return 0
    fi

    echo -n "Stopping node.js server "
    kill "$PID" || exit $?
    rm -f $PIDFILE
    rm -f log/node.log

    return 0
}

# change directory to the scripts location
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
restart)
        shift
        stop; start
        exit $?
        ;;
*)
        echo "Usage: ${0} {start|stop|restart}"
        exit 2
        ;;