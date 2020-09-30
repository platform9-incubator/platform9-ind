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

### To start container with custom pf9-qbert branch
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

### To start container with custom pf9-qbert branch
Above steps will create the containerized hosts with pf9-kube RPM available in the DU. If you want to use a custom codebase, please follow these steps -
1. Check out pf9-qbert along side this repo.
2. Start the container in "dev" mode
```
export NUM_CONTAINERS=<N>
make dev
```

## Debugging nodelet inside the container

Follow the steps under "To start container with custom pf9-qbert branch". The containerized hosts will have golang 1.13 and delve debugger pre-installed. Nodelet codebase is also mounted to appropriate directories on the container so that delve shows the code being executed.
```
docker exec -ti <platform9-in-docker-container> bash
ps aux | grep nodeletd
dlv attach <pid-from-above-command>
```


## System requirements

Single node deployments worked fine on 2017 13"Macbook Pro with i5 processor and 8GB memory.

However multi-node deployments on the same are flaky. I would recommend creating a single VM on df.platform9.net for running multi-node setups. The VM can also be used as a dev VM.

|        |        | Deployment |            |         |      | System Requirements |       |
|:------:|:------:|:----------:|:----------:|:-------:|:----:|:-------------------:|:-----:|
| **Master** | **Worker** |     **CNI**    | **Monitoring** | **MetalLB** | **CPUs** |        **Memory**       |  **Disk** |
|    1   |    0   |   Flannel  |     Yes    |   Yes   |   3  |         6GB         |  30GB |
|    1   |    0   |   Calico   |     Yes    |   Yes   |   3  |         6GB         |  50GB |
|    3   |    1   |   Flannel  |     Yes    |   Yes   |   4  |         15GB        | 100GB |
|    3   |    1   |   Calico  |     Yes    |   Yes   |   4  |         15GB        | 100GB |

## Using a VM on dogfood

Image: ubuntu16-pmk (57089a60-16ea-4668-a5dd-4cc3b62b1e96)

Flavor: m3.xlarge (4 VCPUs / 15GB RAM)

Volume: Change the volume size when creating the VM to at least (20 * number of containerized hosts) + 10 GB. Recommend creating 100GB volume. These volumes are de-duped and thin-provisioned on purestorage array so that should be fine.

Network: Any network is OK to use since we don't use host networking for containerized hosts.

Security group: Set it to "allow all" security group for the tenant in which you are creating the VM.

NOTE:
1. For this VM image you will need to download the docker-compose as mentioned above.
2. After installing docker (`sudo apt install docker.io`), you will need to configure docker to use a lower MTU as the VM is running in OpenStack. To do that add - 
   ```
   {
     "experimental": true,
     "mtu": 1350
   }
   ```
   to `/etc/docker/daemon.json` and restart the docker daemon as `sudo systemctl restart docker`
