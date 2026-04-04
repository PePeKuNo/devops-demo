@echo off
chcp 65001 >nul

set DOCKER_USER=r0uzis
set VERSION=v3
set BUILD_DATE=2026-04-04T00:00:00Z
set NODE_ENV=production
set BACKEND_IMAGE=%DOCKER_USER%/demo-backend:%VERSION%
set FRONTEND_IMAGE=%DOCKER_USER%/demo-frontend:%VERSION%

echo === 0. Usuwanie starych kontenerow ===
docker stop frontend api-a api-b 2>nul
docker rm frontend api-a api-b 2>nul

echo === 0.1 Tworzenie sieci demo-net, jesli nie istnieje ===
docker network inspect demo-net >nul 2>nul || docker network create demo-net

echo === 1. Przebudowanie backendu ===
docker build --build-arg BUILD_DATE=%BUILD_DATE% --build-arg VERSION=%VERSION% --build-arg NODE_ENV=%NODE_ENV% -t %BACKEND_IMAGE% ./backend

echo === 2. Budowanie frontendu ===
docker build --build-arg BUILD_DATE=%BUILD_DATE% --build-arg VERSION=%VERSION% --build-arg NODE_ENV=%NODE_ENV% -t %FRONTEND_IMAGE% ./frontend

echo === 3. Uruchamianie dwoch instancji backendu ===
docker run -d --name api-a --network demo-net -p 3001:3000 -e INSTANCE_ID="Instancja-A" %BACKEND_IMAGE%
docker run -d --name api-b --network demo-net -e INSTANCE_ID="Instancja-B" %BACKEND_IMAGE%

echo === 4. Uruchamianie frontendu ===
docker run -d --name frontend --network demo-net -p 80:8080 %FRONTEND_IMAGE%

echo === Gotowe: http://localhost ===
pause
