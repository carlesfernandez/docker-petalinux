#!/bin/bash

# Default version 2018.3
XILVER=${1:-2018.3}

# Check if the petalinux installer exists
PLNX="resources/petalinux-v${XILVER}-final-installer.run"
if [ ! -f "$PLNX" ] ; then
    echo "$PLNX installer not found"
    exit 1
fi

# Check HTTP server is running
PYTHONV=$(python --version 2>&1 | cut -f2 -d' ')
case $PYTHONV in
    3*) PYTHONHTTP="http.server" ;;
    *) PYTHONHTTP="SimpleHTTPServer" ;;
esac
if ! ps -fC python | grep "$PYTHONHTTP" > /dev/null ; then
    python -m "$PYTHONHTTP" &
    HTTPID=$!
    echo "HTTP Server started as PID $HTTPID"
    trap "kill $HTTPID" EXIT KILL QUIT SEGV INT HUP TERM ERR
fi

echo "Creating Docker image petalinux:$XILVER..."
time docker build . -t petalinux:$XILVER --build-arg XILVER=${XILVER}
[ -n "$HTTPID" ] && kill $HTTPID && echo "Killed HTTP Server"
