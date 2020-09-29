#!/bin/bash

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

function load_container_images() {
    echo "Loading the required docker container images"
    files=/container_images/*.tar
    if [ -d /container_images ]; then
        for file in $files; do
            docker load -i $file
        done
    fi
}

function prep_container() {
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

    ## Make sure the docker directories are present prior to starting docker daemon
    mkdir -p /var/lib/docker/network/files

    ## Explicitly set the storage-driver to vfs
    ## vfs driver works with all host OS (based on trial and error)
    mkdir -p /etc/docker
    echo '{"storage-driver": "vfs"}' > /etc/docker/daemon.json
    
    ## PMK scripts will check `systemctl is-active docker` so start dockerd from systemd unit
    systemctl daemon-reload
    systemctl start docker.service
    sleep 2
    
    ## Need to figure out why pf9 user is not able to access this socket otherwise
    chmod 777 /var/run/docker.sock
    
    ## Mock the getenforce since it is not present in containers
    echo 'echo Permissive' > /usr/local/bin/getenforce
    chmod 777 /usr/local/bin/getenforce

    ## Change loopback DNS to 8.8.8.8
    echo -e 'nameserver 8.8.8.8\noptions ndots:0' > /etc/resolv.conf

    ## Needed for this to work on df, containers still work when deployed locally on Mac.
    ip link set dev eth0 mtu 1400
}

function install_and_configure_pf9ctl() {
    PF9REGION="${PF9REGION:-RegionOne}"
    PF9PROJECT="${PF9PROJECT:-service}"
    /root/get_cli --pf9_account_url "${PF9ACT}" --pf9_email "${PF9USER}" --pf9_password "${PF9PASS}" --pf9_region "${PF9REGION}" --pf9_project "${PF9PROJECT}"
}


function patch_pf9ctl() {
    ## Docker for Mac always injects swap that cannot be unmounted or turned off :(
    echo "  ignore_errors: true" >> /root/pf9/pf9-venv/lib/python3.6/site-packages/pf9/express/roles/disable-swap/tasks/main.yml

    ## We are installing python3.6 but CLI does not fully support python3 yet
    for file in /root/pf9/pf9-venv/lib/python3.6/site-packages/pf9/express/roles/ntp/tasks/main.yml /root/pf9/pf9-venv/lib/python3.6/site-packages/pf9/express/roles/common/tasks/redhat.yml; do
        sed '/^- name: Install .*/a\  vars:\n    ansible_python_interpreter: \/usr\/bin\/python' $file -i
    done
}

function prep_node() {
    echo 'y

    ' | pf9ctl cluster prep-node
}

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

setup_dev_if_necessary() {
    if [ "x${DEV}" != "x" ]; then
        echo "DEV is enabled, so stopping services and patching files"
        systemctl stop pf9-hostagent.service
        systemctl stop pf9-nodeletd.service
        yes | cp /root/local/nodelet/nodeletd /opt/pf9/nodelet/nodeletd
        yes | cp -Rf /root/local/agent/root/opt/pf9/pf9-kube/* /opt/pf9/pf9-kube/
        systemctl start pf9-hostagent.service
        echo "DEV mode: Restarted the services"
    fi
}

prep_container
install_and_configure_pf9ctl
patch_pf9ctl
prep_node
patch_pmk_files
setup_dev_if_necessary &
load_container_images

echo "Node is ready to be added to k8s cluster at ${PF9ACT}"
