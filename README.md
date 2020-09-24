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

Pre-requisites: docker desktop (docker and docker-compose commands are needed)

### 1. Download the necessary images
This needs to be done just once.
```
mkdir -p container_images
docker pull gcr.io/google_containers/hyperkube:v1.17.9
docker save gcr.io/google_containers/hyperkube -o container_images/hyperkube.tar
```

### 2. Run the containers
Replace N with required number of containers.
Please adjust the CPU and memory limits in docker-compose as per your hardware.
The docker-compose file is configured with minimum required CPU and memory for a single node flannel setup with MetalLB and monitoring enabled.
```
docker-compose --compatibility up --detach --scale pmk-node=<N>
```

NOTE: If `make` is installed on mac, you can follow the steps listed for linux.

## To run on linux

Pre-requisites: docker and docker-compose commands must be available

```
export NUM_CONTAINERS=<N>
make run
```
