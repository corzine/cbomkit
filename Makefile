# extract cbomkit version tag from pom.xml
VERSION := $(shell curl -s https://api.github.com/repos/cbomkit/cbomkit/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
# set engine to use for build and compose, default to docker
ENGINE ?= docker
# set COMPOSE to "docker compose" or "podman-compose"
# some versions of "docker-compose" are v1 and are not compatible
# with this "docker compose" which requires v2.x
ifeq (${ENGINE}, docker)
  COMPOSE = ${ENGINE} compose
else
  COMPOSE = ${ENGINE}-compose
endif
# build the backend
build-backend:
	./mvnw clean package
# build the container image for the backend
build-backend-image: build-backend
	$(ENGINE) build \
		-t cbomkit:${VERSION} \
		-f src/main/docker/Dockerfile.jvm \
		. \
		--load
# build the container image for the frontend
build-frontend-image:
	$(ENGINE) build \
		-t cbomkit-frontend:${VERSION} \
		-f frontend/docker/Dockerfile \
		./frontend \
		--load
# run the dev setup using docker/podman compose
dev:
	env CBOMKIT_VERSION=${VERSION} CBOMKIT_VIEWER=false POSTGRESQL_AUTH_USERNAME=cbomkit POSTGRESQL_AUTH_PASSWORD=cbomkit ${COMPOSE} --profile dev up -d
dev-backend:
	env CBOMKIT_VERSION=${VERSION} CBOMKIT_VIEWER=false POSTGRESQL_AUTH_USERNAME=cbomkit POSTGRESQL_AUTH_PASSWORD=cbomkit ${COMPOSE} --profile dev-backend up -d
dev-frontend:
	env CBOMKIT_VERSION=${VERSION} CBOMKIT_VIEWER=false POSTGRESQL_AUTH_USERNAME=cbomkit POSTGRESQL_AUTH_PASSWORD=cbomkit ${COMPOSE} --profile dev-frontend up
# run the prod setup using $(ENGINE) compose
production:
	env CBOMKIT_VERSION=${VERSION} CBOMKIT_VIEWER=false POSTGRESQL_AUTH_USERNAME=cbomkit POSTGRESQL_AUTH_PASSWORD=cbomkit ${COMPOSE} --profile prod up
edge:
	$(ENGINE) pull ghcr.io/cbomkit/cbomkit:edge
	$(ENGINE) pull ghcr.io/cbomkit/cbomkit-frontend:edge
	env CBOMKIT_VERSION=edge CBOMKIT_VIEWER=false POSTGRESQL_AUTH_USERNAME=cbomkit POSTGRESQL_AUTH_PASSWORD=cbomkit ${COMPOSE} --profile prod up
coeus:
	env CBOMKIT_VERSION=${VERSION} CBOMKIT_VIEWER=true ${COMPOSE} --profile viewer up
ext-compliance:
	env CBOMKIT_VERSION=${VERSION} CBOMKIT_VIEWER=false POSTGRESQL_AUTH_USERNAME=cbomkit POSTGRESQL_AUTH_PASSWORD=cbomkit ${COMPOSE} --profile ext-compliance up

deploy:
	helm install cbomkit \
		--set common.clusterDomain=openshift-cluster-d465a2b8669424cc1f37658bec09acda-0000.eu-de.containers.appdomain.cloud \
		--set cbomkit.tag=${VERSION} \
		--set frontend.tag=${VERSION} \
		--set postgresql.auth.username=cbomkit \
		--set postgresql.auth.password=cbomkit \
		./chart

undeploy:
	helm uninstall cbomkit

