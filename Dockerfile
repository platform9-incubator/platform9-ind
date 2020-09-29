FROM centos:centos7

RUN yum install -y https://repo.ius.io/ius-release-el7.rpm; yum -y update; yum clean all; yum -y install git wget vim lvm2 openssl strace systemd which sudo initscripts python36u htop; yum clean all;
RUN dbus-uuidgen > /var/lib/dbus/machine-id && mkdir -p /var/run/dbus && dbus-daemon --config-file=/usr/share/dbus-1/system.conf --print-address

STOPSIGNAL SIGRTMIN+3

# make sure systemd can't start virtual terminals, agetty is a
# pig in containers. See https://bugzilla.redhat.com/show_bug.cgi?id=1350819
RUN rm -f /lib/systemd/system/systemd*udev* && rm -f /lib/systemd/system/getty.target
RUN (cd /lib/systemd/system/sysinit.target.wants/; for i in *; do [ $i == \
systemd-tmpfiles-setup.service ] || rm -f $i; done); \
rm -f /lib/systemd/system/multi-user.target.wants/*;\
rm -f /etc/systemd/system/*.wants/*;\
rm -f /lib/systemd/system/local-fs.target.wants/*; \
rm -f /lib/systemd/system/sockets.target.wants/*udev*; \
rm -f /lib/systemd/system/sockets.target.wants/*initctl*; \
rm -f /lib/systemd/system/basic.target.wants/*;\
rm -f /lib/systemd/system/anaconda.target.wants/*;\
rm -f /usr/lib/tmpfiles.d/systemd-nologin.conf;

# Download a specific version of docker
RUN wget https://download.docker.com/linux/static/stable/x86_64/docker-19.03.12.tgz -O docker.tgz; \
tar --extract \
    --file docker.tgz \
    --strip-components 1 \
    --directory /usr/local/bin/; \
rm docker.tgz;

RUN curl -OL http://pf9.io/get_cli; \
chmod +x get_cli; \
mv get_cli /root/get_cli; \
mkdir -p /root/local/agent /root/local/nodelet;

RUN yum install -y git

# Install go and delve
RUN curl -O https://dl.google.com/go/go1.13.3.linux-amd64.tar.gz; \
sudo tar -C /usr/local -xzf go1.13.3.linux-amd64.tar.gz; \
mkdir -p ~/go; echo "export GOPATH=$HOME/go" >> ~/.bashrc; \
echo "export PATH=$PATH:$HOME/go/bin:/usr/local/go/bin" >> ~/.bashrc; \
source ~/.bashrc; \
go get -u github.com/go-delve/delve/cmd/dlv;

COPY docker.service /lib/systemd/system/docker.service
COPY modprobe.sh /usr/local/bin/modprobe
COPY entrypoint.sh /usr/local/bin/
COPY get_cli.sh /get_cli.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /get_cli.sh

VOLUME [ "/sys/fs/cgroup", "/container_images" ]
ENTRYPOINT ["entrypoint.sh"]
