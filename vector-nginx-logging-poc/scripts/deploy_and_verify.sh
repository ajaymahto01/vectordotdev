#!/usr/bin/env bash
set -euo pipefail

# Simple deploy + verify script for the Vector -> Elasticsearch POC
# Usage: ./scripts/deploy_and_verify.sh [--import-kibana]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/.."

COMPOSE_CMD=""
if command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_CMD="docker-compose"
elif docker compose version >/dev/null 2>&1; then
  COMPOSE_CMD="docker compose"
else
  echo "docker-compose or docker compose is required"
  exit 1
fi

cd "${ROOT_DIR}"

echo "Bringing up the stack using: ${COMPOSE_CMD}"
${COMPOSE_CMD} up --build -d

echo "Waiting for Elasticsearch (http://localhost:9200) to become healthy..."
for i in {1..60}; do
  if curl -sSf http://localhost:9200/_cluster/health >/dev/null 2>&1; then
    echo "Elasticsearch is reachable"
    break
  fi
  sleep 1
done

if ! curl -sSf http://localhost:9200/_cluster/health >/dev/null 2>&1; then
  echo "Elasticsearch did not become available in time. Check 'docker-compose logs elasticsearch'"
  exit 2
fi

echo "Generating sample traffic against nginx to create logs..."
for i in 1 2 3 4 5; do
  curl -sS -o /dev/null http://localhost/ || true
  curl -sS -o /dev/null http://localhost/nonexistent || true
done

echo "Waiting for Vector -> Elasticsearch ingestion (searching for documents)..."
FOUND=0
for i in {1..60}; do
  # use _search to see if any doc exists in our index pattern
  COUNT=$(curl -sS "http://localhost:9200/nginx-logs-*/_count" -H 'Content-Type: application/json' || true)
  if echo "$COUNT" | grep -q '"count"'; then
    # extract number
    NUM=$(echo "$COUNT" | sed -n 's/.*"count"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p')
    NUM=${NUM:-0}
    if [ "$NUM" -gt 0 ]; then
      echo "Found $NUM document(s) in nginx-logs-* indices. Ingestion appears successful."
      FOUND=1
      break
    fi
  fi
  sleep 1
done

if [ "$FOUND" -ne 1 ]; then
  echo "No documents found in Elasticsearch index pattern 'nginx-logs-*' after waiting."
  echo "Check Vector logs: ${COMPOSE_CMD} logs -f vector"
  exit 3
fi

echo "Success: pipeline appears to be working."
echo "Open Kibana at http://localhost:5601 and create an index pattern 'nginx-logs-*' (time field: @timestamp if present)."

if [ "${1:-}" = "--import-kibana" ]; then
  echo "Attempting to create Kibana index pattern via API..."
  # Create saved object id 'nginx-logs-pattern' with title 'nginx-logs-*'
  if curl -sS -X POST "http://localhost:5601/api/saved_objects/index-pattern/nginx-logs-pattern" \
       -H 'kbn-xsrf: true' \
       -H 'Content-Type: application/json' \
       -d '{"attributes":{"title":"nginx-logs-*","timeFieldName":"@timestamp"}}' >/dev/null 2>&1; then
    echo "Kibana index pattern created (nginx-logs-pattern)."
  else
    echo "Failed to create Kibana index pattern via API. You may need to create it manually in the Kibana UI."
  fi
fi

echo "Done."
