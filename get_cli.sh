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

## Create the pf9 user to chown the files
adduser pf9
groupadd pf9group
usermod -a -G pf9group pf9
groupadd docker
usermod -a -G docker pf9

## This has to be done first to prevent PF9 components from changing docker config
mkdir -p /etc/pf9/
echo 'export PF9_MANAGED_DOCKER="false"' >> /etc/pf9/kube_override.env
chown -R pf9:pf9group /etc/pf9/

## PMK scripts expect the docker binary to be at /usr/bin/docker
ln -s /usr/local/bin/docker /usr/bin/docker

## PMK scripts will check `systemctl is-active docker` so start dockerd from systemd unit
systemctl daemon-reload
systemctl start docker.service
sleep 2

## Need to figure out why pf9 user is not able to access this socket otherwise
chmod 777 /var/run/docker.sock

## Mock the getenforce since it is not present in containers
echo 'echo Permissive' > /usr/bin/getenforce
chmod 777 /usr/local/bin/getenforce

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

function patch_pmk_files() {
    ## Unconditionally return that swap is turned off from the tackboard script
    sed 's|swapStat="{ \\"enabled\\": \\"true\\" }"|swapStat="{ \\"enabled\\": \\"false\\" }"|' /opt/pf9/pf9-kube/diagnostics_utils/node_check.sh -i

    ## Remove the swap check from gen_certs.sh
    sed -e '/check_swap_disabled/ s/^#*/#/' /opt/pf9/pf9-kube/base_scripts/gen_certs.sh -i

    ## Set the kubelet flag failSwapOn to false to allow kubelet to run with swap enabled
    sed '/^clusterDomain:.*/a failSwapOn: false' /opt/pf9/pf9-kube/utils.sh -i

    ## conntrack-max-per-core needs to be set to 0 for kube-proxy container to come up.
    ## Without this the container fails to start as it tries to modify a read-only sysctl value.
    sed '/^\s*--proxy-mode.*/a\                              --conntrack-max-per-core 0 \\' /opt/pf9/pf9-kube/utils.sh -i

    ## Remove the getenforce check since there is no getenforce in containers
    sed 's|ret=`getenforce`|ret="Permissive"|' /opt/pf9/pf9-kube/os_centos.sh -i
}

patch_pmk_files

## Node is ready to be added to cluster
echo "Node is ready to be added to k8s cluster at ${PF9ACT}"
