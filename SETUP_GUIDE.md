# Complete Setup Guide: nginx + Vector + Elasticsearch + Kibana

This guide walks you through the complete setup and demonstrates the full logging pipeline.

## Overview

This Docker-based setup demonstrates a complete logging pipeline:
1. **nginx** generates access logs in JSON format
2. **Vector** reads the logs and ships them to Elasticsearch
3. **Elasticsearch** stores the logs
4. **Kibana** provides a web UI to visualize and search the logs

## Quick Start

### 1. Start All Services

```bash
docker compose up -d
```

This will start all four services (nginx, Vector, Elasticsearch, and Kibana).

### 2. Wait for Services to be Ready

```bash
# Check service status
docker compose ps

# Wait for Elasticsearch to be healthy (may take 1-2 minutes)
until curl -s http://localhost:9200/_cluster/health | grep -q '"status":"green\|yellow"'; do
  echo "Waiting for Elasticsearch..."
  sleep 5
done

# Check Kibana is available
curl -s http://localhost:5601/api/status
```

### 3. Generate Some Test Logs

```bash
# Generate traffic to nginx
for i in {1..10}; do
  curl http://localhost:8080
done

# Wait a few seconds for Vector to process and ship the logs
sleep 5
```

### 4. Verify Logs in Elasticsearch

```bash
# Check indices
curl http://localhost:9200/_cat/indices?v

# Count logs
curl http://localhost:9200/nginx-access-*/_count

# View sample logs
curl -s "http://localhost:9200/nginx-access-*/_search?pretty&size=2"
```

### 5. Access Kibana

Open your browser to: **http://localhost:5601**

#### Create a Data View

1. Navigate to **Stack Management** → **Data Views**
2. Click **Create data view**
3. Enter the index pattern: `nginx-access-*`
4. Select the timestamp field: `timestamp`
5. Click **Save data view to Kibana**

#### View Logs in Discover

1. Navigate to **Analytics** → **Discover**
2. Select the `nginx-access-*` data view
3. You should see all the nginx access logs with fields like:
   - `remote_addr`: Client IP address
   - `request`: HTTP request method and path
   - `status`: HTTP status code
   - `http_user_agent`: User agent string
   - `body_bytes_sent`: Response size
   - `request_time`: Request duration
   - And more...

## Services Configuration

### nginx Configuration

- **Port**: 8080
- **Log Format**: JSON (structured logging)
- **Log Location**: `/var/log/nginx/access.log` (mounted volume)
- **Configuration**: `nginx/nginx.conf`

### Vector Configuration

- **Purpose**: Log shipper
- **Source**: Reads from nginx log files
- **Destination**: Elasticsearch
- **Configuration**: `vector/vector.toml`
- **Features**:
  - Parses JSON logs from nginx
  - Adds metadata (log_type, timestamp)
  - Creates daily indices in Elasticsearch

### Elasticsearch

- **Port**: 9200
- **Index Pattern**: `nginx-access-YYYY.MM.DD`
- **Security**: Disabled (for demo purposes only)

### Kibana

- **Port**: 5601
- **Purpose**: Web UI for log exploration and visualization

## Testing the Pipeline

Use the included test script:

```bash
./test-setup.sh
```

This script will:
1. Check if all services are running
2. Generate test traffic
3. Wait for logs to be processed
4. Verify logs in Elasticsearch
5. Display sample log entries

## Monitoring

### View Vector Logs

```bash
docker compose logs -f vector
```

Vector logs show:
- File watching status
- Log parsing results
- Elasticsearch shipping status

### View Nginx Logs

```bash
docker compose logs -f nginx
```

Or directly from the mounted volume:

```bash
tail -f nginx/logs/access.log
```

### Check Elasticsearch Health

```bash
curl http://localhost:9200/_cluster/health?pretty
```

### View All Service Logs

```bash
docker compose logs -f
```

## Stopping the Services

```bash
# Stop all services
docker compose down

# Stop and remove volumes
docker compose down -v
```

## Troubleshooting

### No logs appearing in Elasticsearch

1. Check Vector is running: `docker compose ps vector`
2. Check Vector logs: `docker compose logs vector`
3. Ensure nginx has been accessed to generate logs
4. Verify log files exist: `ls -la nginx/logs/`
5. Check Elasticsearch is accessible: `curl http://localhost:9200`

### Kibana not loading

1. Wait 1-2 minutes for Kibana to fully start
2. Check Kibana logs: `docker compose logs kibana`
3. Verify Elasticsearch is healthy: `curl http://localhost:9200/_cluster/health`

### Vector not shipping logs

1. Check Vector configuration: `docker compose logs vector | grep ERROR`
2. Verify log files are readable: `docker exec vector-shipper ls -la /var/log/nginx/`
3. Restart Vector: `docker compose restart vector`

## Architecture Diagram

```
┌─────────┐      ┌────────┐      ┌────────────────┐      ┌────────┐
│  nginx  │─────▶│ Vector │─────▶│ Elasticsearch  │◀─────│ Kibana │
│  :8080  │      │        │      │     :9200      │      │ :5601  │
└─────────┘      └────────┘      └────────────────┘      └────────┘
    │                                                          │
    │                                                          │
    └──────────────── User accesses logs via UI ──────────────┘
```

## Log Flow

1. **User makes HTTP request** → nginx (:8080)
2. **nginx writes JSON log** → `/var/log/nginx/access.log`
3. **Vector reads log file** → Parses JSON → Adds metadata
4. **Vector ships to Elasticsearch** → Creates document in index `nginx-access-YYYY.MM.DD`
5. **User views logs** → Kibana (:5601) → Queries Elasticsearch → Displays results

## Sample Log Entry

```json
{
  "body_bytes_sent": "615",
  "http_referrer": "",
  "http_user_agent": "curl/8.5.0",
  "log_type": "nginx_access",
  "remote_addr": "172.18.0.1",
  "remote_user": "",
  "request": "GET / HTTP/1.1",
  "request_time": "0.000",
  "status": "200",
  "time_local": "16/Oct/2025:19:37:25 +0000",
  "timestamp": "2025-10-16T19:39:56.082957137Z"
}
```

## Customization

### Change nginx log format

Edit `nginx/nginx.conf` and modify the `log_format json_combined` section.

### Modify Vector pipeline

Edit `vector/vector.toml` to add transformations, filters, or change the destination.

### Add more sources

Vector can collect logs from multiple sources. Add more `[sources.*]` sections in `vector/vector.toml`.

### Query logs in Elasticsearch

```bash
# Search for specific status codes
curl -s "http://localhost:9200/nginx-access-*/_search?pretty" -H 'Content-Type: application/json' -d'
{
  "query": {
    "term": { "status": "200" }
  }
}
'

# Aggregate by user agent
curl -s "http://localhost:9200/nginx-access-*/_search?pretty" -H 'Content-Type: application/json' -d'
{
  "size": 0,
  "aggs": {
    "user_agents": {
      "terms": { "field": "http_user_agent.keyword" }
    }
  }
}
'
```

## Security Considerations

**⚠️ Important**: This setup is for development/testing only!

For production:
- Enable Elasticsearch security features
- Use authentication for all services
- Configure TLS/SSL encryption
- Use proper network segmentation
- Implement access controls in Kibana
- Regular backup of Elasticsearch indices

## Additional Resources

- [Vector Documentation](https://vector.dev/docs/)
- [Elasticsearch Documentation](https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html)
- [Kibana Documentation](https://www.elastic.co/guide/en/kibana/current/index.html)
- [nginx Logging Documentation](https://nginx.org/en/docs/http/ngx_http_log_module.html)
