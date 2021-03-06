NUM_CONTAINERS?=1
IMAGES=$(shell cat images_to_download)
.PHONY: run clean build

container_images/hyperkube.tar:
	mkdir -p container_images
	for image in ${IMAGES}; do docker pull $${image}; imgname=$${image%\:*}; filename=$${imgname##*\/}; docker save $${imgname} -o container_images/$${filename}.tar ; done

build:
	docker-compose build

run: container_images/hyperkube.tar build
	docker-compose --compatibility up --d --scale pmk-node=${NUM_CONTAINERS}

dev-build:
	make -C ../pf9-kube nodelet

dev: container_images/hyperkube.tar dev-build
	docker-compose --compatibility -f docker-compose.yml -f docker-compose.dev.yml up --d --scale pmk-node=${NUM_CONTAINERS}

clean:
	docker-compose down
	rm -f container_images/*

clean-all: clean
	docker image prune
