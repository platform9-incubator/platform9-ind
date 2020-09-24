NUM_CONTAINERS=${NUM_CONTAINERS:-1}
.PHONY: run clean build

container_images/hyperkube.tar:
	mkdir -p container_images
	docker pull gcr.io/google_containers/hyperkube:v1.17.9
	docker save gcr.io/google_containers/hyperkube -o container_images/hyperkube.tar

build:
	docker-compose build

run: container_images/hyperkube.tar build
	docker-compose --compatibility up --detach --scale pmk-node=${NUM_CONTAINERS}

clean:
	docker-compose down
