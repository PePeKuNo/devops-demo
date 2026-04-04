# DevOps Demo

Product Dashboard z backendem `Node.js + Express`, frontendem `React` i `Nginx` jako reverse proxy do dwoch instancji backendu.

## Struktura projektu

- `backend/` - API produktow, endpointy `/health`, `/items`, `/stats`
- `frontend/` - aplikacja React, konfiguracja `nginx.conf`, Dockerfile dla Nginx
- `deploy-2v.bat` - lokalne uruchomienie pod Windows
- `Makefile` - lokalne uruchomienie i komendy `docker buildx`

## Funkcjonalnosc

- `GET /health` zwraca status backendu, uptime, aktualny czas serwera i licznik obsluzonych zadan
- `GET /stats` zwraca liczbe produktow, uptime, czas serwera, liczbe obsluzonych zadan i ID instancji
- widok `Statystyki` w React pokazuje wszystkie nowe pola
- `Nginx` rozdziela ruch miedzy `api-a` i `api-b`
- `Nginx` cache'uje odpowiedzi z `/api/stats` przez 30 sekund

## Docker

### Backend

- multi-stage z etapami `deps` i `production`
- finalny obraz zawiera tylko produkcyjne `node_modules` i kod aplikacji
- uruchamianie jako uzytkownik `node`
- `HEALTHCHECK` sprawdza `GET /health`

### Frontend

- multi-stage z etapami `deps`, `build` i `production`
- etap produkcyjny oparty na obrazie `nginx-unprivileged`
- finalny obraz zawiera tylko statyczny build React i konfiguracje Nginx
- proces dziala jako nie-root
- `HEALTHCHECK` sprawdza `GET /healthz`

## Lokalny start

Windows:

```bat
deploy-2v.bat
```

Linux/macOS:

```bash
make deploy
```

Frontend po starcie jest dostepny pod:

```text
http://localhost
```

## Multi-platform buildx

Tworzenie buildera:

```bash
docker buildx create --name multiarch --use
docker buildx inspect multiarch --bootstrap
```

Publikacja obrazow:

```bash
docker buildx build --builder multiarch --platform linux/amd64,linux/arm64 -t <docker-user>/demo-backend:latest --push ./backend
docker buildx build --builder multiarch --platform linux/amd64,linux/arm64 -t <docker-user>/demo-frontend:latest --push ./frontend
```

Weryfikacja manifestow:

```bash
docker buildx imagetools inspect <docker-user>/demo-backend:latest
docker buildx imagetools inspect <docker-user>/demo-frontend:latest
```
