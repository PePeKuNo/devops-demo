DOCKER_USER ?= r0uzis
NETWORK ?= demo-net
FRONTEND_PORT ?= 8080

.PHONY: help network build-backend build-frontend push-frontend stop remove run-backends run-frontend deploy clean

help:
	@echo "make deploy         - buduje i uruchamia projekt"
	@echo "make build-backend  - buduje obraz backendu"
	@echo "make build-frontend - buduje obraz frontendu"
	@echo "make push-frontend  - wysyla obrazy frontendu do Docker Hub"
	@echo "make stop           - zatrzymuje uruchomione kontenery"
	@echo "make clean          - zatrzymuje i usuwa kontenery"

network:
	@docker network inspect $(NETWORK) >/dev/null 2>&1 || docker network create $(NETWORK)

build-backend:
	docker build -t $(DOCKER_USER)/demo-backend:latest ./backend

build-frontend:
	docker build -t $(DOCKER_USER)/demo-frontend:v2 ./frontend
	docker tag $(DOCKER_USER)/demo-frontend:v2 $(DOCKER_USER)/demo-frontend:latest

push-frontend:
	docker push $(DOCKER_USER)/demo-frontend:v2
	docker push $(DOCKER_USER)/demo-frontend:latest

stop:
	- docker stop frontend api-a api-b

remove:
	- docker rm frontend api-a api-b

run-backends: network
	docker run -d --name api-a --network $(NETWORK) -e INSTANCE_ID=Instancja-A $(DOCKER_USER)/demo-backend:latest
	docker run -d --name api-b --network $(NETWORK) -e INSTANCE_ID=Instancja-B $(DOCKER_USER)/demo-backend:latest

run-frontend: network
	docker run -d --name frontend --network $(NETWORK) -p $(FRONTEND_PORT):80 $(DOCKER_USER)/demo-frontend:v2

deploy: stop remove build-backend build-frontend run-backends run-frontend
	@echo "Aplikacja jest dostepna pod adresem: http://localhost:$(FRONTEND_PORT)"

clean: stop remove
