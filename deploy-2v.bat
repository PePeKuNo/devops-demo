@echo off
chcp 65001 >nul

set DOCKER_USER=r0uzis

echo === 0. Usuwanie starych kontenerow ===
docker stop frontend api-a api-b 2>nul
docker rm frontend api-a api-b 2>nul

echo === 0.1 Tworzenie sieci demo-net, jesli nie istnieje ===
docker network inspect demo-net >nul 2>nul || docker network create demo-net

echo === 1. Przebudowanie backendu ===
docker build -t %DOCKER_USER%/demo-backend:latest ./backend

echo === 2. Budowanie frontendu jako nowa wersja v2 ===
docker build -t %DOCKER_USER%/demo-frontend:v2 ./frontend
docker tag %DOCKER_USER%/demo-frontend:v2 %DOCKER_USER%/demo-frontend:latest

echo === 3. Publikacja frontendu v2 do rejestru ===
docker push %DOCKER_USER%/demo-frontend:v2
docker push %DOCKER_USER%/demo-frontend:latest

echo === 4. Uruchamianie dwoch instancji backendu ===
:: Flaga -e przekazuje zmienna srodowiskowa INSTANCE_ID do kontenera
docker run -d --name api-a --network demo-net -e INSTANCE_ID="Instancja-A" %DOCKER_USER%/demo-backend:latest
docker run -d --name api-b --network demo-net -e INSTANCE_ID="Instancja-B" %DOCKER_USER%/demo-backend:latest

echo === 5. Uruchamianie zaktualizowanego frontendu v2 ===
docker run -d --name frontend --network demo-net -p 8080:80 %DOCKER_USER%/demo-frontend:v2

echo === Gotowe: http://localhost:8080 ===
pause
