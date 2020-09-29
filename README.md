## Platform9 IN Docker

### Create the env file for your setup -
```
PF9ACT=https://<DU_FQDN>
PF9USER=<USERNAME>
PF9PASS=<PASSWORD>
PF9REGION=<REGION|Default:RegionOne>
PF9PROJECT=<PROJECT_NAME|Default:service>
```

## To run on Mac

Pre-requisites: docker desktop (docker and docker-compose >1.27.2 commands are needed)
Recommended: make (available once xcode command line tools are installed for xcode > 4.3)

### 1. Download the necessary images
This needs to be done just once.
```
mkdir -p container_images
for image in `cat images_to_download`;
    do docker pull $${image}; imgname=$${image%\:*}; filename=$${imgname##*\/}; docker save $${imgname} -o container_images/$${filename}.tar ;
done
```

### 2. Run the containers
Replace N with required number of containers.
Please adjust the CPU and memory limits in docker-compose as per your hardware.
The docker-compose file is configured with minimum required CPU and memory for a single node flannel setup with MetalLB and monitoring enabled.
```
docker-compose --compatibility up --detach --scale pmk-node=<N>
```

### To start container with custom pf9-qbert repo
Above steps will create the containerized hosts with pf9-kube RPM available in the DU. If you want to use a custom codebase, please follow these steps -
1. Check out pf9-qbert along side this repo.
2. Create the nodelet binary
```
cd pf9-qbert
make nodelet
```
3. Start the container in "dev" mode
```
docker-compose --compatibility -f docker-compose.yml -f docker-compose.dev.yml up --detach --scale pmk-node=<N>
```

NOTE: If `make` is installed on mac, you can follow the steps listed for linux.

## To run on linux

Pre-requisites: docker, docker-compose >1.27.2, make

### Download right version of docker-compose
```
sudo curl -L https://github.com/docker/compose/releases/download/1.27.2/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

### Start the containers
```
export NUM_CONTAINERS=<N>
make run
```

### To start container with custom pf9-qbert repo
Above steps will create the containerized hosts with pf9-kube RPM available in the DU. If you want to use a custom codebase, please follow these steps -
1. Check out pf9-qbert along side this repo.
2. Start the container in "dev" mode
```
export NUM_CONTAINERS=<N>
make dev
```

## System requirements

|        |        | Deployment |            |         |      | System Requirements |       |
|:------:|:------:|:----------:|:----------:|:-------:|:----:|:-------------------:|:-----:|
| Master | Worker |     CNI    | Monitoring | MetalLB | CPUs |        Memory       |  Disk |
|    1   |    0   |   Flannel  |     Yes    |   Yes   |   3  |         6GB         |  30GB |
|    1   |    0   |   Calico   |     Yes    |   Yes   |   3  |         6GB         |  50GB |
|    3   |    1   |   Flannel  |     Yes    |   Yes   |   4  |         15GB        | 100GB |
