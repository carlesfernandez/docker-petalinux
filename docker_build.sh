#!/bin/bash
# SPDX-FileCopyrightText: 2020, Carles Fernandez-Prades <carles.fernandez@cttc.es>
# SPDX-License-Identifier: MIT

# Default version 2019.1
XILVER=${1:-2019.1}

# Default Vivado build number
XXXX_XXXX=${2:-0524_1430}

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
# shellcheck disable=SC2009
if ! ps -fC python | grep "$PYTHONHTTP" > /dev/null ; then
    python -m "$PYTHONHTTP" &
    HTTPID=$!
    echo "HTTP Server started as PID $HTTPID"
    trap 'kill $HTTPID' EXIT QUIT SEGV INT HUP TERM ERR
fi

echo "Creating Docker image petalinux:$XILVER..."
time docker build . -t petalinux:"$XILVER" --build-arg XILVER="${XILVER}" --build-arg XXXX_XXXX="${XXXX_XXXX}"
[ -n "$HTTPID" ] && kill $HTTPID && echo "Killed HTTP Server"
