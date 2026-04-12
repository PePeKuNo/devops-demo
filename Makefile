NETWORK ?= product-net
POSTGRES_CONTAINER ?= product-postgres
REDIS_CONTAINER ?= product-redis
BACKEND_CONTAINER ?= product-backend
FRONTEND_CONTAINER ?= product-frontend
POSTGRES_VOLUME ?= product-postgres-data-v2
BACKEND_DEPS_VOLUME ?= product-backend-node-modules-dev
BACKEND_IMAGE ?= product-dashboard-backend
FRONTEND_IMAGE ?= product-dashboard-frontend
REGISTRY ?= localhost:5000
MULTIARCH_BACKEND_IMAGE ?= $(REGISTRY)/product-dashboard-backend
MULTIARCH_FRONTEND_IMAGE ?= $(REGISTRY)/product-dashboard-frontend
VERSION ?= v2
IMAGE_TAG ?= $(VERSION)
BUILD_DATE ?= 2026-04-12T00:00:00Z
PLATFORMS ?= linux/amd64,linux/arm64
BUILDER ?= multiarch-local

.PHONY: start stop run-dev backup restore inspect-volumes build-backend build-frontend clean buildx-create buildx-inspect push-backend-multiarch push-frontend-multiarch inspect-backend-manifest inspect-frontend-manifest

start:
	sh ./start.sh

stop:
	- docker rm -f $(FRONTEND_CONTAINER) $(BACKEND_CONTAINER) $(REDIS_CONTAINER) $(POSTGRES_CONTAINER)

run-dev:
	sh ./run_dev.sh

backup:
	sh ./backup.sh

restore:
	sh ./restore.sh $(ARCHIVE)

inspect-volumes:
	sh ./inspect_volumes.sh

build-backend:
	docker build --build-arg BUILD_DATE=$(BUILD_DATE) --build-arg VERSION=$(VERSION) --build-arg NODE_ENV=production -t $(BACKEND_IMAGE):$(IMAGE_TAG) ./backend

build-frontend:
	docker build --build-arg BUILD_DATE=$(BUILD_DATE) --build-arg VERSION=$(VERSION) --build-arg NODE_ENV=production -t $(FRONTEND_IMAGE):$(IMAGE_TAG) ./frontend

buildx-create:
	docker buildx create --name $(BUILDER) --driver docker-container --driver-opt network=host --buildkitd-config ./buildkitd.toml --use

buildx-inspect:
	docker buildx inspect $(BUILDER) --bootstrap

push-backend-multiarch:
	docker buildx build --builder $(BUILDER) --platform $(PLATFORMS) --build-arg BUILD_DATE=$(BUILD_DATE) --build-arg VERSION=$(VERSION) --build-arg NODE_ENV=production -t host.docker.internal:5000/product-dashboard-backend:$(IMAGE_TAG) --push ./backend

push-frontend-multiarch:
	docker buildx build --builder $(BUILDER) --platform $(PLATFORMS) --build-arg BUILD_DATE=$(BUILD_DATE) --build-arg VERSION=$(VERSION) --build-arg NODE_ENV=production -t host.docker.internal:5000/product-dashboard-frontend:$(IMAGE_TAG) --push ./frontend

inspect-backend-manifest:
	docker buildx imagetools inspect $(MULTIARCH_BACKEND_IMAGE):$(IMAGE_TAG)

inspect-frontend-manifest:
	docker buildx imagetools inspect $(MULTIARCH_FRONTEND_IMAGE):$(IMAGE_TAG)

clean: stop
	- docker volume rm $(POSTGRES_VOLUME) $(BACKEND_DEPS_VOLUME)
	- docker network rm $(NETWORK)
