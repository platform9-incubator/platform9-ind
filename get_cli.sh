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

    local KUBE_OVERRIDE=/etc/pf9/kube_override.env
    local SYSCTL_CONF=/etc/sysctl.conf
    
    ## This has to be done first to prevent PF9 components from changing docker config
    mkdir -p /etc/pf9/
    echo 'export PF9_MANAGED_DOCKER="false"' >> $KUBE_OVERRIDE
    echo 'export ALLOW_SWAP="true"' >> $KUBE_OVERRIDE
    echo 'export MAX_NAT_CONN="0"' >> $KUBE_OVERRIDE
    chown -R pf9:pf9group /etc/pf9/

    # Enable IPv6 support
    echo 'net.ipv6.conf.all.disable_ipv6 = 0' >> $SYSCTL_CONF
    echo 'net.ipv6.conf.default.disable_ipv6 = 0' >> $SYSCTL_CONF
    echo 'net.ipv6.conf.docker0.disable_ipv6 = 0' >> $SYSCTL_CONF
    echo 'net.ipv6.conf.ip6tnl0.disable_ipv6 = 0' >> $SYSCTL_CONF
    echo 'net.ipv6.conf.lo.disable_ipv6 = 0' >> $SYSCTL_CONF
    sysctl -p
    
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
    echo 'echo Permissive' > /usr/sbin/getenforce
    chmod 777 /usr/sbin/getenforce

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
    echo "  ignore_errors: true" >> /root/pf9/pf9-venv/lib/python2.7/site-packages/pf9/express/roles/disable-swap/tasks/main.yml

    ## We are installing python3.6 but CLI does not fully support python3 yet
    for file in /root/pf9/pf9-venv/lib/python3.6/site-packages/pf9/express/roles/ntp/tasks/main.yml /root/pf9/pf9-venv/lib/python3.6/site-packages/pf9/express/roles/common/tasks/redhat.yml; do
        sed '/^- name: Install .*/a\  vars:\n    ansible_python_interpreter: \/usr\/bin\/python' $file -i
    done
}

function prep_node() {
    echo 'y

    ' | pf9ctl cluster prep-node
}

setup_dev_if_necessary() {
    if [ "x${DEV}" != "x" ]; then
        echo "DEV is enabled, so stopping services and patching files"
        systemctl stop pf9-nodeletd.service pf9-hostagent.service
        dev_dir=/root/local/pf9-kube
        yes | cp ${dev_dir}/build/pf9-kube/nodelet/bin/nodeletd /opt/pf9/nodelet/nodeletd
        mv /opt/pf9/pf9-kube/defaults.env /opt/pf9/pf9-kube/defaults.env.bk
        yes | cp -Rf ${dev_dir}/root/opt/pf9/pf9-kube/* /opt/pf9/pf9-kube/
        yes | cp -Rf ${dev_dir}/root/opt/pf9/hostagent/extensions/* /opt/pf9/hostagent/extensions/
        mv /opt/pf9/pf9-kube/defaults.env.bk /opt/pf9/pf9-kube/defaults.env
        mkdir -p /go/src/github.com/platform9
        ln -s $dev_dir/nodelet/ /go/src/github.com/platform9/
        systemctl start pf9-hostagent.service
        cp /root/local/debugger/pf9-nodeletd-debugger.sh /pf9-nodeletd-debugger.sh
        chmod +x /pf9-nodeletd-debugger.sh
        cp /root/local/debugger/pf9-nodeletd-debugger.service /lib/systemd/system/
        systemctl daemon-reload
        systemctl enable pf9-nodeletd-debugger.service
        systemctl start pf9-nodeletd-debugger.service
        echo "DEV mode: Restarted the services"
    fi
}

prep_container
install_and_configure_pf9ctl
patch_pf9ctl
prep_node
setup_dev_if_necessary
load_container_images

echo "Node is ready to be added to k8s cluster at ${PF9ACT}"
