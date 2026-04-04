DOCKER_USER ?= r0uzis
NETWORK ?= demo-net
FRONTEND_PORT ?= 80
BACKEND_HEALTH_PORT ?= 3001
BACKEND_IMAGE ?= $(DOCKER_USER)/demo-backend
FRONTEND_IMAGE ?= $(DOCKER_USER)/demo-frontend
IMAGE_TAG ?= latest
VERSION ?= v3
BUILD_DATE ?= 2026-04-04T00:00:00Z
NODE_ENV ?= production
PLATFORMS ?= linux/amd64,linux/arm64
BUILDER ?= multiarch

.PHONY: help network build-backend build-frontend stop remove run-backends run-frontend deploy clean buildx-create buildx-inspect push-backend-multiarch push-frontend-multiarch inspect-backend-manifest inspect-frontend-manifest

help:
	@echo "make deploy                    - buduje i uruchamia projekt"
	@echo "make build-backend             - buduje lokalny obraz backendu"
	@echo "make build-frontend            - buduje lokalny obraz frontendu"
	@echo "make buildx-create             - tworzy builder docker buildx"
	@echo "make buildx-inspect            - pokazuje konfiguracje buildera"
	@echo "make push-backend-multiarch    - buduje i publikuje backend multiarch"
	@echo "make push-frontend-multiarch   - buduje i publikuje frontend multiarch"
	@echo "make inspect-backend-manifest  - sprawdza manifest backendu"
	@echo "make inspect-frontend-manifest - sprawdza manifest frontendu"
	@echo "make stop                      - zatrzymuje uruchomione kontenery"
	@echo "make clean                     - zatrzymuje i usuwa kontenery"

network:
	@docker network inspect $(NETWORK) >/dev/null 2>&1 || docker network create $(NETWORK)

build-backend:
	docker build --build-arg BUILD_DATE=$(BUILD_DATE) --build-arg VERSION=$(VERSION) --build-arg NODE_ENV=$(NODE_ENV) -t $(BACKEND_IMAGE):$(IMAGE_TAG) ./backend

build-frontend:
	docker build --build-arg BUILD_DATE=$(BUILD_DATE) --build-arg VERSION=$(VERSION) --build-arg NODE_ENV=$(NODE_ENV) -t $(FRONTEND_IMAGE):$(IMAGE_TAG) ./frontend

buildx-create:
	docker buildx create --name $(BUILDER) --use

buildx-inspect:
	docker buildx inspect $(BUILDER) --bootstrap

push-backend-multiarch:
	docker buildx build --builder $(BUILDER) --platform $(PLATFORMS) --build-arg BUILD_DATE=$(BUILD_DATE) --build-arg VERSION=$(VERSION) --build-arg NODE_ENV=$(NODE_ENV) -t $(BACKEND_IMAGE):$(IMAGE_TAG) --push ./backend

push-frontend-multiarch:
	docker buildx build --builder $(BUILDER) --platform $(PLATFORMS) --build-arg BUILD_DATE=$(BUILD_DATE) --build-arg VERSION=$(VERSION) --build-arg NODE_ENV=$(NODE_ENV) -t $(FRONTEND_IMAGE):$(IMAGE_TAG) --push ./frontend

inspect-backend-manifest:
	docker buildx imagetools inspect $(BACKEND_IMAGE):$(IMAGE_TAG)

inspect-frontend-manifest:
	docker buildx imagetools inspect $(FRONTEND_IMAGE):$(IMAGE_TAG)

stop:
	- docker stop frontend api-a api-b

remove:
	- docker rm frontend api-a api-b

run-backends: network
	docker run -d --name api-a --network $(NETWORK) -p $(BACKEND_HEALTH_PORT):3000 -e INSTANCE_ID=Instancja-A $(BACKEND_IMAGE):$(IMAGE_TAG)
	docker run -d --name api-b --network $(NETWORK) -e INSTANCE_ID=Instancja-B $(BACKEND_IMAGE):$(IMAGE_TAG)

run-frontend: network
	docker run -d --name frontend --network $(NETWORK) -p $(FRONTEND_PORT):8080 $(FRONTEND_IMAGE):$(IMAGE_TAG)

deploy: stop remove build-backend build-frontend run-backends run-frontend
	@echo "Aplikacja jest dostepna pod adresem: http://localhost"

clean: stop remove
