@echo off
chcp 65001 >nul

set REGISTRY_CONTAINER=product-registry
set REGISTRY_HOST=localhost:5000
set NETWORK_NAME=product-net
set POSTGRES_CONTAINER=product-postgres
set REDIS_CONTAINER=product-redis
set BACKEND_CONTAINER=product-backend
set FRONTEND_CONTAINER=product-frontend
set POSTGRES_VOLUME=product-postgres-data-v2
set VERSION=v2
set BUILD_DATE=2026-04-12T00:00:00Z
set BACKEND_IMAGE=%REGISTRY_HOST%/product-dashboard-backend:%VERSION%
set FRONTEND_IMAGE=%REGISTRY_HOST%/product-dashboard-frontend:%VERSION%
set POSTGRES_DB=products
set POSTGRES_USER=products
set POSTGRES_PASSWORD=products
set FRONTEND_BIND_SOURCE=%~dp0frontend\nginx.conf

echo === Preparing network and volume ===
docker network inspect %NETWORK_NAME% >nul 2>nul || docker network create %NETWORK_NAME%
docker volume inspect %POSTGRES_VOLUME% >nul 2>nul || docker volume create %POSTGRES_VOLUME%

echo === Removing previous containers ===
docker rm -f %FRONTEND_CONTAINER% %BACKEND_CONTAINER% %REDIS_CONTAINER% %POSTGRES_CONTAINER% >nul 2>nul

echo === Starting local registry ===
docker container inspect %REGISTRY_CONTAINER% >nul 2>nul
if errorlevel 1 (
  docker run -d --restart always -p 5000:5000 --name %REGISTRY_CONTAINER% registry:2
) else (
  docker start %REGISTRY_CONTAINER% >nul 2>nul
)
docker network connect %NETWORK_NAME% %REGISTRY_CONTAINER% >nul 2>nul

echo === Building and pushing backend ===
docker build --build-arg BUILD_DATE=%BUILD_DATE% --build-arg VERSION=%VERSION% --build-arg NODE_ENV=production -t %BACKEND_IMAGE% .\backend
docker push %BACKEND_IMAGE%

echo === Building and pushing frontend ===
docker build --build-arg BUILD_DATE=%BUILD_DATE% --build-arg VERSION=%VERSION% --build-arg NODE_ENV=production -t %FRONTEND_IMAGE% .\frontend
docker push %FRONTEND_IMAGE%

echo === Pulling images from registry ===
docker pull %BACKEND_IMAGE%
docker pull %FRONTEND_IMAGE%

echo === Starting PostgreSQL ===
docker run -d --name %POSTGRES_CONTAINER% --network %NETWORK_NAME% -e POSTGRES_DB=%POSTGRES_DB% -e POSTGRES_USER=%POSTGRES_USER% -e POSTGRES_PASSWORD=%POSTGRES_PASSWORD% -v %POSTGRES_VOLUME%:/var/lib/postgresql/data postgres:16-alpine

echo === Starting Redis ===
docker run -d --name %REDIS_CONTAINER% --network %NETWORK_NAME% --tmpfs /data:rw,noexec,nosuid,size=64m redis:7-alpine

echo === Waiting for PostgreSQL ===
:wait_postgres
docker exec %POSTGRES_CONTAINER% pg_isready -U %POSTGRES_USER% -d %POSTGRES_DB% >nul 2>nul
if errorlevel 1 (
  timeout /t 2 >nul
  goto wait_postgres
)

echo === Waiting for Redis ===
:wait_redis
docker exec %REDIS_CONTAINER% redis-cli ping >nul 2>nul
if errorlevel 1 (
  timeout /t 1 >nul
  goto wait_redis
)

echo === Starting backend ===
docker run -d --name %BACKEND_CONTAINER% --network %NETWORK_NAME% -p 3000:3000 -e PORT=3000 -e POSTGRES_HOST=%POSTGRES_CONTAINER% -e POSTGRES_PORT=5432 -e POSTGRES_DB=%POSTGRES_DB% -e POSTGRES_USER=%POSTGRES_USER% -e POSTGRES_PASSWORD=%POSTGRES_PASSWORD% -e REDIS_URL=redis://%REDIS_CONTAINER%:6379 --tmpfs /tmp:rw,noexec,nosuid,size=64m %BACKEND_IMAGE%

echo === Starting frontend ===
docker run -d --name %FRONTEND_CONTAINER% --network %NETWORK_NAME% -p 80:8080 -v "%FRONTEND_BIND_SOURCE%:/etc/nginx/conf.d/default.conf:ro" %FRONTEND_IMAGE%

echo === Ready ===
echo Registry: http://localhost:5000/v2/_catalog
echo Frontend: http://localhost
echo Backend:  http://localhost:3000
pause
