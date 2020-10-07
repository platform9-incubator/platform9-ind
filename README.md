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

## Debugging Nodelet inside the container

Follow the steps under "To start container with custom pf9-qbert branch". The containerized hosts will have golang 1.13 and delve debugger pre-installed. Nodelet codebase is also mounted to appropriate directories on the container so that delve shows the code being executed. A debugger systemd is also pre-started which attaches dlv to running nodeletd in headless mode and listens on port 40000.

Since we are exposing port 40000 statically outside the container it is recommended to start just ***one*** container. 

### To debug directly on container
```
docker exec -ti <platform9-in-docker-container> bash
systemctl stop pf9-nodeletd-debugger.service
dlv attach `ps aux | grep /opt/pf9/nodelet/nodeletd | grep -v grep | grep -v log | awk '{print $2}' | xargs`
```

### To debug from outside the container
You will need the dlv binary installed on your host for this.
```
dlv connect 127.0.0.1:40000
```

### To debug from outside the container using VS Code
Add the following debug launch config
```
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Debug-nodeletd",
            "type": "go",
            "request": "attach",
            "mode": "remote",
            "remotePath": "/go/src/github.com/platform9/nodelet",
            "port": 40000,
            "host": "127.0.0.1"
        }
    ]
}
```
Debugging from VS Code should work as usual now.

NOTE:

1. Clicking "restart" from the VS Code debug menu borks the debugger and no breakpoints will be hit. When that happens, exec into the container and restart the `pf9-nodeletd` and `pf9-nodeletd-debugger` services.

## Using the generated kubeconfig
After downloading the kubeconfig from the UI to your host, you will need to modify the server field of the kubeconfig so that kubectl can access the kube apiserver running inside the container. Port 443 is exposed on all containerized hosts as a random port on the host. 

1. Get the host port to connect by running the following command
```
docker inspect <master-node-container-name-or-id> | grep HostPort | grep -v 40000 | grep -v '""'
```

2. Edit the downloaded kubeconfig

Update the server field in kubeconfig to connect to `127.0.0.1:<host-port>`
```
server: 'https://127.0.0.1:<host-port>'
```

`kubectl` commands should now work as expected from the host.

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
