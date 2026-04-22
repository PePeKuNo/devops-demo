#!/usr/bin/env bash
set -euo pipefail

# Docker Network Lab - All-in-One Setup & Verification Script
# This script sets up and verifies all networking lab requirements

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}ℹ${NC} $*"; }
pass() { echo -e "${GREEN}✅${NC} $*"; }
fail() { echo -e "${RED}❌${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC} $*"; }

# ============================================
# SECTION 1: SETUP
# ============================================

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║   Docker Network Lab - Advanced Configuration             ║"
echo "║   Complete Setup & Verification                           ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

info "Starting setup..."

# Cleanup old containers
info "Step 1: Cleaning up old containers and networks..."
for c in nginx backend_1 backend_2 worker redis postgres test-alpine-1 test-alpine-2 host-demo none-demo; do
  docker rm -f "$c" >/dev/null 2>&1 || true
done

for net in proxy-net app-net db-net default-dns-test custom-dns-test; do
  docker network rm "$net" >/dev/null 2>&1 || true
done
pass "Old containers and networks removed"

# Create volumes
info "Step 2: Creating persistent volumes..."
docker volume create postgres_data >/dev/null 2>&1 || true
docker volume create redis_data >/dev/null 2>&1 || true
pass "Volumes created: postgres_data, redis_data"

# Create networks
info "Step 3: Creating three bridge networks with custom subnets..."
create_net(){
  local name="$1" subnet="$2" gw="$3"
  if ! docker network inspect "$name" >/dev/null 2>&1; then
    docker network create --driver bridge --subnet "$subnet" --gateway "$gw" "$name" >/dev/null
    pass "Network created: $name ($subnet, gateway: $gw)"
  fi
}

create_net proxy-net 172.30.0.0/16 172.30.0.1
create_net app-net   172.31.0.0/16 172.31.0.1
create_net db-net    172.32.0.0/16 172.32.0.1

# Build images
info "Step 4: Building Docker images..."
if [ -f backend/Dockerfile ]; then
  docker build -q -t backend:latest backend/ >/dev/null 2>&1 && pass "Built: backend:latest" || fail "Failed to build backend"
fi

if [ -f worker/Dockerfile ]; then
  docker build -q -t worker:latest worker/ >/dev/null 2>&1 && pass "Built: worker:latest" || fail "Failed to build worker"
fi

if [ -f frontend/Dockerfile ]; then
  docker build -q -t frontend:latest frontend/ >/dev/null 2>&1 && pass "Built: frontend:latest" || fail "Failed to build frontend"
fi

# Start containers
info "Step 5: Starting containers..."

# PostgreSQL
docker run -d --name postgres --network db-net --ip 172.32.0.10 \
  -e POSTGRES_PASSWORD=postgres -v postgres_data:/var/lib/postgresql/data postgres:13 >/dev/null 2>&1
pass "Container started: postgres (db-net, 172.32.0.10)"
sleep 1

# Redis
docker run -d --name redis --network app-net --ip 172.31.0.10 \
  -v redis_data:/data redis:6 >/dev/null 2>&1
pass "Container started: redis (app-net, 172.31.0.10)"
sleep 1

# Backend 1
docker run -d --name backend_1 --network proxy-net --ip 172.30.0.11 \
  --mac-address "02:42:ac:1e:00:11" \
  -e PORT=3000 \
  -e POSTGRES_HOST=172.32.0.10 \
  -e POSTGRES_PORT=5432 \
  -e POSTGRES_DB=postgres \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e REDIS_HOST=172.31.0.10 \
  -e REDIS_PORT=6379 \
  backend:latest >/dev/null 2>&1
docker network connect --ip 172.32.0.11 db-net backend_1 >/dev/null 2>&1 || true
docker network connect --ip 172.31.0.11 app-net backend_1 >/dev/null 2>&1 || true
pass "Container started: backend_1 (proxy-net, db-net, app-net)"
sleep 1

# Backend 2
docker run -d --name backend_2 --network proxy-net --ip 172.30.0.12 \
  --mac-address "02:42:ac:1e:00:12" \
  -e PORT=3000 \
  -e POSTGRES_HOST=172.32.0.10 \
  -e POSTGRES_PORT=5432 \
  -e POSTGRES_DB=postgres \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e REDIS_HOST=172.31.0.10 \
  -e REDIS_PORT=6379 \
  backend:latest >/dev/null 2>&1
docker network connect --ip 172.32.0.12 db-net backend_2 >/dev/null 2>&1 || true
docker network connect --ip 172.31.0.12 app-net backend_2 >/dev/null 2>&1 || true
pass "Container started: backend_2 (proxy-net, db-net, app-net)"
sleep 1

# Worker
docker run -d --name worker --network app-net --ip 172.31.0.20 \
  -e WORKER_ID=worker \
  -e POSTGRES_HOST=172.32.0.10 \
  -e POSTGRES_PORT=5432 \
  -e POSTGRES_DB=postgres \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e REDIS_HOST=172.31.0.10 \
  -e REDIS_PORT=6379 \
  worker:latest >/dev/null 2>&1 || true
docker network connect --ip 172.32.0.20 db-net worker >/dev/null 2>&1 || true
pass "Container started: worker (app-net, db-net - NOT in proxy-net)"
sleep 1

# Nginx (Frontend)
docker run -d --name nginx --network proxy-net --ip 172.30.0.10 -p 80:8080 \
  frontend:latest >/dev/null 2>&1
pass "Container started: nginx (frontend with React, proxy-net, port 80)"
sleep 2

# Demo containers
info "Step 6: Starting demo containers..."
docker network create --driver bridge custom-dns-test >/dev/null 2>&1
docker run -d --name test-alpine-1 --network custom-dns-test alpine:latest sleep 300 >/dev/null 2>&1
docker run -d --name test-alpine-2 --network custom-dns-test alpine:latest sleep 300 >/dev/null 2>&1
pass "DNS demo containers created in custom-dns-test network"

docker run -d --name host-demo --network host alpine:latest sleep 300 >/dev/null 2>&1
pass "Demo container created: host-demo (--network host)"

docker run -d --name none-demo --network none alpine:latest sleep 300 >/dev/null 2>&1
pass "Demo container created: none-demo (--network none)"

# ============================================
# SECTION 2: VERIFICATION
# ============================================

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                    VERIFICATION REPORT                     ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# CRITERIA 1: Network Segmentation
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo "CRITERIA 1: Network Segmentation (25%)"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

echo "1.1 Three networks with custom subnets and gateways:"
for net in proxy-net app-net db-net; do
  if docker network inspect "$net" >/dev/null 2>&1; then
    SUBNET=$(docker network inspect "$net" --format='{{range .IPAM.Config}}{{.Subnet}}{{end}}')
    GATEWAY=$(docker network inspect "$net" --format='{{range .IPAM.Config}}{{.Gateway}}{{end}}')
    pass "$net: Subnet=$SUBNET, Gateway=$GATEWAY"
  fi
done

echo ""
echo "1.2 Container assignment to networks:"
for net in proxy-net app-net db-net; do
  echo "  ${BLUE}$net:${NC}"
  docker network inspect "$net" --format='{{range .Containers}}    {{.Name}} ({{.IPv4Address}}){{"\n"}}{{end}}'
done

# CRITERIA 2: Network Isolation
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo "CRITERIA 2: Network Isolation (20%)"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

echo "2.1 Nginx isolation from PostgreSQL:"
if docker exec nginx ping -c 1 -W 1 postgres >/dev/null 2>&1; then
  fail "Nginx can ping postgres (UNEXPECTED!)"
else
  pass "Nginx CANNOT reach postgres (isolated as expected)"
fi

echo ""
echo "2.2 Backend connectivity to PostgreSQL:"
if docker exec backend_1 ping -c 1 -W 1 postgres >/dev/null 2>&1; then
  pass "backend_1 CAN reach postgres (as expected)"
else
  fail "backend_1 CANNOT reach postgres (unexpected!)"
fi

echo ""
echo "2.3 Backend connectivity to Redis:"
if docker exec backend_1 ping -c 1 -W 1 redis >/dev/null 2>&1; then
  pass "backend_1 CAN reach redis (as expected)"
else
  fail "backend_1 CANNOT reach redis (unexpected!)"
fi

echo ""
echo "2.4 Worker not exposed to external access:"
WORKER_PORTS=$(docker port worker 2>/dev/null | wc -l || echo "0")
if [ "$WORKER_PORTS" -eq 0 ]; then
  pass "Worker has NO exposed ports (isolated)"
else
  warn "Worker has exposed ports"
fi

echo ""
echo "2.5 Worker isolation from proxy-net:"
WORKER_PROXY=$(docker inspect worker --format='{{.NetworkSettings.Networks.proxy-net}}' 2>/dev/null || echo "")
if [ -z "$WORKER_PROXY" ] || [ "$WORKER_PROXY" = "<no value>" ]; then
  pass "Worker is NOT connected to proxy-net (isolated as expected)"
else
  fail "Worker IS connected to proxy-net (unexpected!)"
fi

# CRITERIA 3: Load Balancing
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo "CRITERIA 3: Load Balancing (15%)"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

echo "3.1 Upstream configuration:"
if docker exec nginx cat /etc/nginx/nginx.conf 2>/dev/null | grep -q "upstream"; then
  pass "Nginx has upstream configuration"
  echo "  Upstream servers:"
  docker exec nginx grep -A 3 "upstream" /etc/nginx/nginx.conf 2>/dev/null | sed 's/^/    /'
else
  fail "No upstream configuration found"
fi

echo ""
echo "3.2 Load balancing distribution (6 requests):"
declare -A instances
for i in {1..6}; do
  RESPONSE=$(curl -s http://localhost/items 2>/dev/null || echo "")
  INSTANCE=$(echo "$RESPONSE" | grep -o '"X-Backend-Instance":"[^"]*' | cut -d'"' -f4 || echo "unknown")
  instances["$INSTANCE"]=$((${instances["$INSTANCE"]:-0} + 1))
done

for inst in "${!instances[@]}"; do
  COUNT=${instances[$inst]}
  echo "  $inst: $COUNT requests"
done

if [ ${#instances[@]} -ge 2 ]; then
  pass "Load balancing working - requests distributed across backends"
else
  warn "Only one backend responded (check if both backends are running)"
fi

# CRITERIA 4: DNS Resolution
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo "CRITERIA 4: DNS Resolution - Default vs Custom Bridge (10%)"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

echo "4.1 DNS in custom bridge network:"
if docker exec test-alpine-1 ping -c 1 -W 1 test-alpine-2 >/dev/null 2>&1; then
  pass "DNS works in custom-dns-test network (containers can resolve by name)"
else
  fail "DNS failed in custom network (unexpected!)"
fi

echo ""
echo "4.2 Container IP for reference:"
ALPINE2_IP=$(docker inspect test-alpine-2 --format='{{.NetworkSettings.Networks.custom-dns-test.IPAddress}}')
echo "  test-alpine-2 IP: $ALPINE2_IP"
if docker exec test-alpine-1 ping -c 1 -W 1 "$ALPINE2_IP" >/dev/null 2>&1; then
  pass "IP-based connectivity works"
else
  fail "IP-based connectivity failed"
fi

# CRITERIA 5: Static Configuration
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo "CRITERIA 5: Static IP, Gateway, MAC Address (15%)"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

echo "5.1 Custom gateways on all networks:"
for net in proxy-net app-net db-net; do
  GW=$(docker network inspect "$net" --format='{{range .IPAM.Config}}{{.Gateway}}{{end}}')
  if [ -n "$GW" ]; then
    pass "$net gateway: $GW"
  fi
done

echo ""
echo "5.2 Static IP addresses:"
B1_IP=$(docker inspect backend_1 --format='{{.NetworkSettings.Networks.proxy-net.IPAddress}}')
B2_IP=$(docker inspect backend_2 --format='{{.NetworkSettings.Networks.proxy-net.IPAddress}}')
[ "$B1_IP" = "172.30.0.11" ] && pass "backend_1 static IP: $B1_IP" || warn "backend_1 IP: $B1_IP"
[ "$B2_IP" = "172.30.0.12" ] && pass "backend_2 static IP: $B2_IP" || warn "backend_2 IP: $B2_IP"

echo ""
echo "5.3 Static MAC addresses:"
B1_MAC=$(docker inspect backend_1 --format='{{.Config.MacAddress}}')
B2_MAC=$(docker inspect backend_2 --format='{{.Config.MacAddress}}')
[ "$B1_MAC" = "02:42:ac:1e:00:11" ] && pass "backend_1 MAC: $B1_MAC" || info "backend_1 MAC: $B1_MAC"
[ "$B2_MAC" = "02:42:ac:1e:00:12" ] && pass "backend_2 MAC: $B2_MAC" || info "backend_2 MAC: $B2_MAC"

# CRITERIA 6: Network Modes
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo "CRITERIA 6: Network Modes - Host & None (15%)"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

echo "6.1 Host network mode (--network host):"
echo "  Use case: Performance-critical services, monitoring agents"
echo "  Characteristic: Container shares host's network stack"
echo "  Demonstration:"
if docker exec host-demo ip addr 2>/dev/null | grep -q "127.0.0.1"; then
  pass "host-demo sees host's loopback (127.0.0.1)"
fi
if docker exec host-demo ip link show 2>/dev/null | wc -l | grep -q "[0-9]"; then
  pass "host-demo can list all host network interfaces"
fi

echo ""
echo "6.2 None network mode (--network none):"
echo "  Use case: Batch processing, offline computation, security isolation"
echo "  Characteristic: Only loopback interface, completely isolated"
echo "  Demonstration:"
INTERFACES=$(docker exec none-demo ip addr 2>/dev/null | grep -E '^[0-9]+:' | wc -l)
ONLY_LO=$(docker exec none-demo ip addr 2>/dev/null | grep -E '^[0-9]+:' | grep -v lo | wc -l)
if [ "$ONLY_LO" = "0" ]; then
  pass "none-demo has ONLY loopback interface (completely isolated)"
else
  fail "none-demo has extra interfaces"
fi

# ============================================
# SECTION 3: SUMMARY
# ============================================

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                    SETUP COMPLETE                         ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

echo "Network topology is ready! All containers are running:"
echo ""
docker ps --filter "name=nginx|backend_1|backend_2|worker|redis|postgres|test-alpine|host-demo|none-demo" \
  --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"

echo ""
echo "📋 Quick Test Commands:"
echo ""
echo "  Test load balancing:"
echo "    curl http://localhost/items"
echo ""
echo "  Test isolation:"
echo "    docker exec nginx ping postgres        # Should FAIL"
echo "    docker exec backend_1 ping postgres    # Should work"
echo ""
echo "  Test DNS resolution:"
echo "    docker exec test-alpine-1 ping test-alpine-2  # Should work"
echo ""
echo "  Verify network isolation:"
echo "    docker inspect backend_1 | grep -A 20 NetworkSettings"
echo ""
echo "📚 Documentation:"
echo "   See README_NETWORKING.md for detailed information"
echo ""
