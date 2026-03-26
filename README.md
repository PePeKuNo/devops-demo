# DevOps Demo

To jest prosty projekt zaliczeniowy z:
- `backendem` w `Node.js + Express`
- `frontendem` w `React`
- `Nginxem` jako reverse proxy
- dwoma instancjami backendu do load balancingu
- cache dla `/api/stats` po stronie Nginxa

## Struktura projektu

- `backend/` - API do produktów i statystyk
- `frontend/` - aplikacja React oraz konfiguracja `nginx.conf`
- `deploy-2v.bat` - uruchomienie pod Windows
- `Makefile` - uruchomienie pod Linux/macOS lub w innych środowiskach z `make`


## Co robi projekt

- strona `Produkty` pobiera listę z backendu
- formularz dodaje nowy produkt przez `POST /items`
- strona `Statystyki` pokazuje liczbę produktów i ID instancji backendu
- `Nginx` rozdziela ruch między `api-a` i `api-b`
- `Nginx` cache'uje odpowiedź z `/api/stats` przez 30 sekund

## Wymagania

- Docker
- Docker Hub login, jeśli obraz ma być wysłany do rejestru
- `make` na systemach Unix-like

## Uruchomienie w Windows

Używam gotowego pliku:

```bat
deploy-2v.bat
```

Skrypt sam sprawdza sieć `demo-net` i tworzy ją, jeśli jeszcze nie istnieje.

## Uruchomienie w Linux/macOS

Najpierw mogę zobaczyć dostępne komendy:

```bash
make help
```

Główny scenariusz uruchomienia:

```bash
make deploy
```

Jeśli chcę podać inny login Docker Hub:

```bash
make deploy DOCKER_USER=twoj_login
```

Jeśli chcę wysłać frontend do Docker Hub:

```bash
make push-frontend DOCKER_USER=twoj_login
```

## Ręczna kontrola działania

Po uruchomieniu aplikacja powinna być dostępna pod adresem:

```text
http://localhost:8080
```

Podczas sprawdzania mogę pokazać:

1. Na stronie `Produkty` wyświetla się lista produktów.
2. Nowy produkt dodaje się przez formularz bez odświeżenia strony.
3. Na stronie `Statystyki` widać liczbę produktów i ID instancji backendu.
4. Powtarzane żądania do `/api/stats` w ciągu 30 sekund mogą wracać z cache.
5. Backend działa w dwóch kontenerach: `api-a` i `api-b`.

## Przydatne komendy Docker

```bash
docker ps
docker logs frontend
docker logs api-a
docker logs api-b
```
