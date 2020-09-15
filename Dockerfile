FROM centos:centos7

RUN yum -y update; yum clean all
RUN yum -y install wget vim lvm2 openssl strace systemd which sudo initscripts; yum clean all;
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
RUN mkdir -p /run/systemd/system
RUN wget https://download.docker.com/linux/static/stable/x86_64/docker-19.03.12.tgz -O docker.tgz; \
tar --extract \
    --file docker.tgz \
    --strip-components 1 \
    --directory /usr/local/bin/; \
rm docker.tgz; \
mkdir -p /var/lib/docker/network/files/;

COPY dind /dind
COPY docker-entrypoint.sh /usr/local/bin/
COPY modprobe.sh /usr/local/bin/modprobe
COPY entrypoint.sh /usr/local/bin/
COPY get_cli.sh /get_cli.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/entrypoint.sh /get_cli.sh /dind

VOLUME [ "/sys/fs/cgroup" ]
ENTRYPOINT ["entrypoint.sh"]
CMD ["sh"]
