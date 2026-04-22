PRODUCT_NETWORK ?= product-net
FRONTEND_CONTAINER ?= product-frontend
BACKEND_CONTAINER ?= product-backend
POSTGRES_CONTAINER ?= product-postgres
REDIS_CONTAINER ?= product-redis
REGISTRY_CONTAINER ?= product-registry
POSTGRES_VOLUME ?= product-postgres-data-v2

.PHONY: start stop verify inspect clean buildx-v2 evidence

start:
	bash ./start.sh

buildx-v2:
	bash ./build-multiplatform-v2.sh

verify:
	bash ./verify-requirements.sh

evidence:
	bash ./generate-evidence.sh

inspect:
	docker network inspect $(PRODUCT_NETWORK)

stop:
	- docker rm -f $(FRONTEND_CONTAINER) $(BACKEND_CONTAINER) $(POSTGRES_CONTAINER) $(REDIS_CONTAINER)

clean: stop
	- docker rm -f $(REGISTRY_CONTAINER)
	- docker network rm $(PRODUCT_NETWORK)
	- docker volume rm $(POSTGRES_VOLUME)
