#!/bin/sh

mkdir -p /var/lib/docker/network/files

setsid /dind dockerd > /var/log/dockerd.log & 2>&1

setsid /get_cli.sh &

exec /usr/sbin/init
