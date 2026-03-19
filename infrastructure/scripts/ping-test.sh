#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────
# Infrastructure Ping Test
# Verifies that PostgreSQL, Redis, Kafka, and Consul
# containers are reachable from the host.
# ─────────────────────────────────────────────────────────
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASS=0
FAIL=0

check() {
  local name="$1"
  shift
  if "$@" > /dev/null 2>&1; then
    printf "  ${GREEN}✓${NC} %-20s UP\n" "$name"
    ((PASS++))
  else
    printf "  ${RED}✗${NC} %-20s DOWN\n" "$name"
    ((FAIL++))
  fi
}

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║    Internview Infrastructure Ping Test       ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# ── PostgreSQL ──────────────────────────────────────────
echo "▸ PostgreSQL"
check "PostgreSQL (5432)" docker exec internview-postgres pg_isready -U internview
echo ""

# ── Redis ───────────────────────────────────────────────
echo "▸ Redis"
check "Redis (6379)" docker exec internview-redis redis-cli ping
echo ""

# ── Kafka ───────────────────────────────────────────────
echo "▸ Kafka"
check "Kafka (9092)" docker exec internview-kafka /opt/bitnami/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list
echo ""

# ── Consul ──────────────────────────────────────────────
echo "▸ Consul"
check "Consul (8500)" curl -sf http://localhost:8500/v1/status/leader
echo ""

# ── Summary ─────────────────────────────────────────────
echo "──────────────────────────────────────────────"
printf "  Results:  ${GREEN}%d passed${NC}  ${RED}%d failed${NC}\n" "$PASS" "$FAIL"
echo "──────────────────────────────────────────────"

if [ "$FAIL" -gt 0 ]; then
  echo ""
  printf "  ${YELLOW}⚠  Some components are DOWN. Run:${NC}\n"
  echo "     cd infrastructure && docker compose up -d"
  echo ""
  exit 1
fi

echo ""
printf "  ${GREEN}All infrastructure components are healthy!${NC}\n"
echo ""
