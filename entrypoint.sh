#!/bin/sh

mkdir -p /var/lib/docker/network/files
# /usr/local/bin/docker-entrypoint.sh "$@" > /var/log/docker-entrypoint.log & 2>&1
setsid /dind dockerd > /var/log/dockerd.log & 2>&1
setsid /get_cli.sh &
exec /usr/sbin/init
