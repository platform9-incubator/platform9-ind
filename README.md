## Platform9 IN Docker

### Building the container image

`docker build --rm -t centos7-dind .`

### Create the env file for your setup -
```
PF9ACT=https://<DU_FQDN>
PF9USER=<USERNAME>
PF9PASS=<PASSWORD>
```

## 2 ways to create the nodes:
### 1. Running a single container host

```
docker run -d --rm -ti -e=container=docker  -v /sys/fs/cgroup:/sys/fs/cgroup:ro --tmpfs /run --privileged=True --memory 1g --memory-swap 0 --name hack13 --env-file ./env centos7-dind
```

### 2. Prepping 3 Nodes with docker-compose

```
docker-compose up
```