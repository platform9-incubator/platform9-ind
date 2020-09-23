#!/bin/sh

# This script must sleep 10-20s so that system gets initialized
setsid /get_cli.sh $@ &

# Initialize systemd and init
# NOTE: THIS CANNOT RUN IN BACKGROUND
mkdir -p /run/systemd/system
exec /usr/sbin/init
