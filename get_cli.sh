#!/bin/sh

sleep 20
export LANG=en_US.UTF-8
export LC_CTYPE="en_US.UTF-8"
export LC_NUMERIC="en_US.UTF-8"
export LC_TIME="en_US.UTF-8"
export LC_COLLATE="en_US.UTF-8"
export LC_MONETARY="en_US.UTF-8"
export LC_MESSAGES="en_US.UTF-8"
export LC_PAPER="en_US.UTF-8"
export LC_NAME="en_US.UTF-8"
export LC_ADDRESS="en_US.UTF-8"
export LC_TELEPHONE="en_US.UTF-8"
export LC_MEASUREMENT="en_US.UTF-8"
export LC_IDENTIFICATION="en_US.UTF-8"

## Download and run the latest PF9 CLI
curl -OL http://pf9.io/get_cli
chmod +x get_cli
./get_cli --pf9_account_url "${PF9ACT}" --pf9_email "${PF9USER}" --pf9_password "${PF9PASS}" --pf9_region RegionOne --pf9_project service

## Docker for Mac always injects swap that cannot be unmounted or turned off :(
FILE_TO_PATCH=/root/pf9/pf9-venv/lib/python2.7/site-packages/pf9/express/roles/disable-swap/tasks/main.yml
echo "  ignore_errors: true" >> ${FILE_TO_PATCH}

echo 'y

' | pf9ctl cluster prep-node

sed -i -e '$ d' ${FILE_TO_PATCH}

## Node is ready to be added to cluster
## Patch more files to ignore swap on
