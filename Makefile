.PHONY: build run

build:
	docker build --rm --squash --compress -t centos7-dind .

run:
	docker run -d --rm -ti -e=container=docker  -v /sys/fs/cgroup:/sys/fs/cgroup:ro --tmpfs /run --privileged=True --env-file ./env --name hack13 --cpus 2 --memory 4g centos7-dind

clean:
	docker stop hack13 || true
	docker rmi centos7-dind || true
