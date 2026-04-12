# DevOps Demo

Product Dashboard with:

- backend: `Node.js + Express`
- frontend: `React + Nginx`
- database: `PostgreSQL`
- cache: `Redis`

The repository now covers both the base task and the second task from the screenshots:

- production-like startup without Docker Compose, only `docker run`
- PostgreSQL data persisted in a named volume
- Redis data stored in `tmpfs`
- frontend `nginx.conf` mounted from host via bind mount
- backend developer mode with bind mount and automatic reload
- backup / restore / inspect scripts for named volumes

## Requirements

- Docker Desktop
- WSL / Linux / macOS shell for `*.sh` scripts
- Node.js only if you want to run backend tests on the host

## Production-like start

Linux / macOS / WSL:

```sh
./start.sh
```

Windows:

```bat
deploy-2v.bat
```

Services after startup:

- frontend: `http://localhost`
- backend: `http://localhost:3000`
- health: `http://localhost:3000/health`
- items: `http://localhost:3000/items`
- stats: `http://localhost:3000/stats`
- local registry: `http://localhost:5000/v2/_catalog`

## Developer mode

Run:

```sh
./run_dev.sh
```

What it does:

- ensures `product-net`
- ensures PostgreSQL named volume `product-postgres-data-v2`
- ensures dev dependencies volume `product-backend-node-modules-dev`
- starts PostgreSQL and Redis if needed
- replaces `product-backend` with a dev container
- mounts `./backend` into `/app`
- starts `nodemon -L` so host file edits reload the API without `docker build`

Why there are two named volumes now:

- `product-postgres-data-v2` for PostgreSQL data
- `product-backend-node-modules-dev` for dev container dependencies

This also makes `inspect_volumes.sh` show at least two application volumes, which was part of the review criteria.

## Volume scripts

Create DB backup:

```sh
./backup.sh
```

Restore DB backup:

```sh
./restore.sh ./artifacts/backups/<archive-name>.tar.gz
```

Inspect named volumes:

```sh
./inspect_volumes.sh
```

## Verification

### Backend tests

```sh
npm test
```

Result:

```text
Test Suites: 2 passed, 2 total
Tests:       2 passed, 2 total
```

### Hot reload proof without docker build

1. Start dev mode:

```sh
./run_dev.sh
```

2. Initial API response from `/health`:

```json
{"status":"ok","uptimeSeconds":8.948,"serverTime":"2026-04-12T18:28:38.353Z","requestCount":1,"backendInstanceId":"6eb749ef92d7","responseSignature":"server.js response v2","postgres":"up","redis":"up"}
```

3. Edit `backend/server.js` on the host and change:

```js
const responseSignature = 'server.js response v2';
```

to:

```js
const responseSignature = 'server.js response v3';
```

4. Container logs show automatic restart, without `docker build`:

```text
[nodemon] restarting due to changes...
[nodemon] starting `node server.js`
Backend dziala na porcie 3000
```

5. New `/health` response after the file edit:

```json
{"status":"ok","uptimeSeconds":16.85,"serverTime":"2026-04-12T18:29:08.384Z","requestCount":1,"backendInstanceId":"6eb749ef92d7","responseSignature":"server.js response v3","postgres":"up","redis":"up"}
```

### backup.sh sample output

```text
==> Creating backup from volume product-postgres-data-v2
Backup created: /mnt/c/Users/Богдан/Desktop/devops-demo/artifacts/backups/product-postgres-data-v2-20260412T183013Z.tar.gz
```

### restore.sh sample output

Backup was created when `items` contained 4 rows. After that one more item was added, then restore was executed.

```text
==> Restoring backup /mnt/c/Users/Богдан/Desktop/devops-demo/./artifacts/backups/product-postgres-data-v2-20260412T183013Z.tar.gz into volume product-postgres-data-v2
==> Stopping running PostgreSQL container
==> Waiting for PostgreSQL after restore
Restore verified. items table rows: 4
```

After restore, `GET /items` returned:

```json
[{"id":1,"name":"Laptop"},{"id":2,"name":"Smartfon"},{"id":3,"name":"Klawiatura"},{"id":4,"name":"Backup proof item"}]
```

The post-backup item was removed by restore, which confirms that the archive was actually restored.

### inspect_volumes.sh sample output

```text
Volume: product-postgres-data-v2
  mountpoint: /var/lib/docker/volumes/product-postgres-data-v2/_data
  size_kib: 46952
  containers: product-postgres

Volume: product-backend-node-modules-dev
  mountpoint: /var/lib/docker/volumes/product-backend-node-modules-dev/_data
  size_kib: 71912
  containers: product-backend
```

## Useful make targets

```sh
make start
make run-dev
make backup
make restore ARCHIVE=./artifacts/backups/<archive-name>.tar.gz
make inspect-volumes
make stop
make clean
```
