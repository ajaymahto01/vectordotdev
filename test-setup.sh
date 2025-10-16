#!/bin/bash

# Test script for the nginx + Vector + Elasticsearch + Kibana setup

echo "=== Testing the Logging Pipeline ==="
echo ""

# Check if services are running
echo "1. Checking if all services are running..."
docker compose ps
echo ""

# Generate some test traffic
echo "2. Generating test traffic to nginx..."
for i in {1..5}; do
  curl -s http://localhost:8080 > /dev/null
  echo "  Request $i sent"
done
echo ""

# Wait for logs to be processed
echo "3. Waiting for logs to be processed by Vector..."
sleep 5
echo ""

# Check Elasticsearch indices
echo "4. Checking Elasticsearch indices..."
curl -s http://localhost:9200/_cat/indices?v
echo ""

# Count total logs
echo "5. Counting total logs in Elasticsearch..."
curl -s "http://localhost:9200/nginx-access-*/_count" | jq .
echo ""

# Sample some logs
echo "6. Sampling logs from Elasticsearch..."
curl -s "http://localhost:9200/nginx-access-*/_search?pretty&size=2" | jq '.hits.hits[]._source' | head -20
echo ""

# Check Kibana status
echo "7. Checking Kibana status..."
KIBANA_STATUS=$(curl -s http://localhost:5601/api/status | jq -r '.status.overall.level')
echo "  Kibana status: $KIBANA_STATUS"
echo ""

echo "=== Test Complete ==="
echo ""
echo "Next steps:"
echo "  1. Open Kibana at http://localhost:5601"
echo "  2. Go to Management → Stack Management → Data Views"
echo "  3. Create a data view with pattern: nginx-access-*"
echo "  4. Go to Analytics → Discover to view the logs"
echo ""
