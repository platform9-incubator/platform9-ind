#!/bin/bash

/root/go/bin/dlv attach `ps aux | grep /opt/pf9/nodelet/nodeletd | grep -v grep | grep -v log | awk '{print $2}' | xargs` --listen=:40000 --headless=true --api-version=2