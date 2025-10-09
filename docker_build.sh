#!/bin/bash
# SPDX-FileCopyrightText: 2020, Carles Fernandez-Prades <carles.fernandez@cttc.es>
# SPDX-License-Identifier: MIT

# Default version 2018.3
XILVER=${1:-2018.3}

# Default Vivado build number
XXXX_XXXX=${2:-1207_2324}

# Check if the petalinux installer exists
PLNX="resources/petalinux-v${XILVER}-final-installer.run"
if [ ! -f "$PLNX" ] ; then
    echo "$PLNX installer not found"
    exit 1
fi

# Check python command
PYTHON_CMD=$(command -v python 2>/dev/null || \
             command -v python3 2>/dev/null || \
             command -v "$(compgen -c | grep -E '^python3([0-9]+)?(\.[0-9]+)?$' | sort -V | tail -1)" 2>/dev/null)

if [ -z "$PYTHON_CMD" ]; then
    echo "Error: No Python interpreter found." >&2
    exit 1
fi

# Check HTTP server is running
PYTHONV=$($PYTHON_CMD --version 2>&1 | cut -f2 -d' ')
case $PYTHONV in
    3*) PYTHONHTTP="http.server" ;;
    *) PYTHONHTTP="SimpleHTTPServer" ;;
esac
# shellcheck disable=SC2009
if ! ps -fC $PYTHON_CMD | grep "$PYTHONHTTP" > /dev/null ; then
    $PYTHON_CMD -m "$PYTHONHTTP" &
    HTTPID=$!
    echo "HTTP Server started as PID $HTTPID"
    trap 'kill $HTTPID' EXIT QUIT SEGV INT HUP TERM ERR
fi

echo "Creating Docker image petalinux:$XILVER..."
time docker build . -t petalinux:"$XILVER" --build-arg XILVER="${XILVER}" --build-arg XXXX_XXXX="${XXXX_XXXX}"
[ -n "$HTTPID" ] && kill $HTTPID && echo "Killed HTTP Server"
