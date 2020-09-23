.PHONY: run clean

run:
	docker-compose --compatibility up --detach --scale pmk-node=2
clean:
	docker-compose down
