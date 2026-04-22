# Docker Network Lab - Zaawansowana Konfiguracja Sieci

Projekt demonstracyjny przedstawiający zaawansowaną konfigurację sieci Docker z segmentacją, izolacją i load balancingiem.

## 📋 Architektura

### Komponenty
- **Frontend (React)** - Interfejs użytkownika z nginx
- **Backend (Node.js)** - API REST (2 instancje dla load balancingu)
- **Worker** - Przetwarzanie zadań w tle
- **PostgreSQL** - Baza danych
- **Redis** - Cache i kolejka zadań

### Sieci Docker
- **proxy-net** (172.30.0.0/16) - Frontend i backend
- **app-net** (172.31.0.0/16) - Backend, worker, Redis
- **db-net** (172.32.0.0/16) - Backend, worker, PostgreSQL

## 🚀 Szybki Start

### Wymagania
- Docker
- Docker Compose (opcjonalnie)
- Bash

### Uruchomienie

```bash
bash lab.sh
```

Skrypt automatycznie:
1. Czyści stare kontenery i sieci
2. Tworzy wolumeny dla danych
3. Buduje obrazy Docker
4. Uruchamia wszystkie kontenery
5. Weryfikuje konfigurację

### Dostęp do Aplikacji

- **Frontend**: http://localhost/
- **API**: http://localhost/api/items
- **Health Check**: http://localhost/api/health
- **Stats**: http://localhost/api/stats

## 🔒 Izolacja Sieci

### Zasady Segmentacji

| Kontener | proxy-net | app-net | db-net | Porty |
|----------|-----------|---------|--------|-------|
| nginx (frontend) | ✅ | ❌ | ❌ | 80 |
| backend_1 | ✅ | ✅ | ✅ | - |
| backend_2 | ✅ | ✅ | ✅ | - |
| worker | ❌ | ✅ | ✅ | - |
| redis | ❌ | ✅ | ❌ | - |
| postgres | ❌ | ❌ | ✅ | - |

### Weryfikacja Izolacji

```bash
# Nginx NIE może połączyć się z PostgreSQL (oczekiwane)
docker exec nginx ping -c 3 postgres

# Backend MOŻE połączyć się z PostgreSQL
docker exec backend_1 ping -c 3 postgres

# Worker NIE jest dostępny z zewnątrz
docker port worker
```

## ⚖️ Load Balancing

Nginx automatycznie balansuje ruch między `backend_1` i `backend_2`.

### Test Balansowania

```bash
# Wykonaj 10 żądań i sprawdź dystrybucję
for i in {1..10}; do 
  curl -s -I http://localhost/api/items | grep "X-Backend-Instance"
done | sort | uniq -c
```

Oczekiwany wynik: ~5 żądań do każdego backendu.

## 📊 Monitorowanie

### Status Kontenerów

```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Networks}}"
```

### Logi

```bash
# Backend
docker logs backend_1

# Worker
docker logs worker

# Frontend/Nginx
docker logs nginx
```

### Statystyki

```bash
curl http://localhost/api/stats
```

## 🛠️ Struktura Projektu

```
.
├── backend/          # Node.js API
│   ├── app.js
│   ├── worker.js
│   ├── cache.js
│   ├── db.js
│   └── Dockerfile
├── frontend/         # React UI
│   ├── src/
│   ├── nginx.conf
│   └── Dockerfile
├── worker/           # Worker container
│   └── Dockerfile
├── proxy/            # Nginx config (opcjonalnie)
│   └── nginx.conf
└── lab.sh           # Główny skrypt uruchomieniowy
```

## 🧪 Testowanie

### Dodawanie Produktu

```bash
curl -X POST http://localhost/api/items \
  -H "Content-Type: application/json" \
  -d '{"name":"Test Product"}'
```

### Pobieranie Listy

```bash
curl http://localhost/api/items
```

### Health Check

```bash
curl http://localhost/api/health
```

## 🔧 Czyszczenie

```bash
# Zatrzymaj wszystkie kontenery
docker stop $(docker ps -q)

# Usuń kontenery
docker rm nginx backend_1 backend_2 worker redis postgres

# Usuń sieci
docker network rm proxy-net app-net db-net

# Usuń wolumeny (UWAGA: usuwa dane!)
docker volume rm postgres_data redis_data
```

## 📝 Notatki

- Worker przetwarza zadania z kolejki Redis
- PostgreSQL przechowuje dane produktów
- Wszystkie kontenery mają health checks
- Dane są persystowane w wolumenach Docker

## 🎯 Kluczowe Funkcje

✅ Segmentacja sieci z custom subnet/gateway  
✅ Izolacja między warstwami (frontend/backend/database)  
✅ Load balancing między instancjami backend  
✅ Worker bez ekspozycji portów  
✅ Automatyczna weryfikacja konfiguracji  
✅ Health checks dla wszystkich serwisów  
✅ Persystencja danych w wolumenach  

## 📚 Więcej Informacji

Projekt demonstracyjny dla celów edukacyjnych - zaawansowana konfiguracja sieci Docker.
