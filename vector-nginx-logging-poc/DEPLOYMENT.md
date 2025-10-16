# Vector Nginx Logging POC - Deployment Guide

This guide provides step-by-step instructions for deploying and verifying the Vector-based log shipping pipeline.

## Overview

This POC demonstrates a complete log shipping pipeline using:
- **Nginx**: Web server generating access and error logs
- **Vector**: Log collection and shipping agent
- **Elasticsearch**: Log storage and indexing
- **Kibana**: Log visualization and analysis

## Prerequisites

- Docker and Docker Compose installed
- At least 2GB of free RAM
- Ports 80, 5601, and 9200 available

## Quick Start

### 1. Deploy the Stack

From the `vector-nginx-logging-poc` directory:

```bash
docker compose up --build -d
```

This will:
- Build the Nginx container with custom configuration
- Pull and start Elasticsearch 7.10.1
- Pull and start Kibana 7.10.1
- Pull and start Vector 0.23.0

### 2. Verify Services

Check that all containers are running:

```bash
docker compose ps
```

Expected output:
```
NAME                                       STATUS
vector-nginx-logging-poc-elasticsearch-1   Up
vector-nginx-logging-poc-kibana-1          Up
vector-nginx-logging-poc-nginx-1           Up
vector-nginx-logging-poc-vector-1          Up
```

### 3. Check Elasticsearch Health

```bash
curl http://localhost:9200/_cluster/health?pretty
```

Expected response should show `"status": "yellow"` or `"status": "green"`.

### 4. Generate Sample Traffic

Create some nginx access logs:

```bash
# Successful requests
for i in {1..10}; do curl http://localhost/; done

# 404 errors
for i in {1..5}; do curl http://localhost/nonexistent; done
```

### 5. Verify Logs in Elasticsearch

Check that logs are being indexed:

```bash
curl -s "http://localhost:9200/nginx-logs-*/_count" -H 'Content-Type: application/json'
```

Search for recent logs:

```bash
curl -s 'http://localhost:9200/nginx-logs-*/_search?pretty' -H 'Content-Type: application/json' -d'{"size":2}'
```

### 6. Access Kibana

Open your browser and navigate to: http://localhost:5601

#### Create Index Pattern

1. Go to **Stack Management** → **Index patterns**
2. Click **Create index pattern**
3. Enter `nginx-logs-*` as the index pattern name
4. Click **Next step**
5. Select `@timestamp` as the time field
6. Click **Create index pattern**

#### View Logs in Discover

1. Navigate to **Discover** (hamburger menu → Analytics → Discover)
2. Select the `nginx-logs-*` index pattern
3. Adjust the time range if needed (default is "Last 15 minutes")
4. You should see your nginx access logs with parsed fields like:
   - `clientip`
   - `request`
   - `response` (HTTP status code)
   - `bytes`
   - `verb` (HTTP method)
   - `agent` (User-Agent)

## Architecture

### Data Flow

```
Nginx → Access/Error Logs → Vector → Elasticsearch → Kibana
         (/var/log/nginx)     (Parse & Ship)   (Store)   (Visualize)
```

### Vector Pipeline

Vector reads nginx logs and performs the following transformations:

1. **Access Logs**: Parsed using COMBINEDAPACHELOG grok pattern
   - Extracts: clientip, request, response, bytes, verb, agent, etc.
   - Timestamp converted to ISO 8601 format

2. **Error Logs**: Passed through with metadata
   - Tagged with `log_type: error`

3. **Elasticsearch Sink**: Ships all processed logs to ES
   - Index pattern: `nginx-logs-%Y.%m.%d`
   - Compression: gzip enabled

## Configuration Files

### Key Files

- `docker-compose.yml` - Container orchestration
- `nginx/nginx.conf` - Main nginx configuration
- `nginx/conf.d/default.conf` - Server block configuration
- `vector/vector.toml` - Vector pipeline configuration
- `elasticsearch/elasticsearch.yml` - Elasticsearch settings
- `kibana/kibana.yml` - Kibana settings

### Vector Configuration Highlights

```toml
# Source: nginx access logs
[sources.nginx_access]
type = "file"
include = ["/var/log/nginx/access.log"]

# Transform: parse access logs
[transforms.parse_access]
type = "grok_parser"
pattern = "%{COMBINEDAPACHELOG}"

# Transform: convert timestamp
[transforms.convert_timestamp]
type = "remap"
# Converts nginx timestamp to ISO 8601

# Sink: send to Elasticsearch
[sinks.elasticsearch]
type = "elasticsearch"
endpoint = "http://elasticsearch:9200"
index = "nginx-logs-%Y.%m.%d"
```

## Troubleshooting

### Container Issues

If containers are restarting:

```bash
# Check logs for specific service
docker compose logs nginx
docker compose logs vector
docker compose logs elasticsearch
docker compose logs kibana
```

### No Logs in Elasticsearch

1. Verify Vector is reading logs:
   ```bash
   docker compose logs vector | grep -i error
   ```

2. Check file permissions:
   ```bash
   ls -la vector-nginx-logging-poc/logs/nginx/
   ```

3. Verify Elasticsearch is accepting data:
   ```bash
   curl http://localhost:9200/_cluster/health
   ```

### Vector Not Starting

Common issues:
- Configuration syntax errors in `vector.toml`
- Elasticsearch not yet ready (Vector will retry)

Check Vector logs:
```bash
docker compose logs vector --tail 50
```

## Stopping the Stack

```bash
# Stop all containers
docker compose down

# Stop and remove volumes (will delete Elasticsearch data)
docker compose down --volumes
```

## Performance Notes

- **Elasticsearch**: Requires ~1GB RAM minimum
- **Log Rotation**: Not configured in this POC - implement for production
- **Security**: This setup has no authentication - not suitable for production

## Next Steps

For production deployment:
1. Enable Elasticsearch security features
2. Configure TLS for all connections
3. Set up log rotation
4. Configure backup/restore for Elasticsearch
5. Tune Elasticsearch heap size based on log volume
6. Add monitoring and alerting
7. Consider using Elasticsearch ILM for index lifecycle management

## Verification Checklist

- [ ] All 4 containers running
- [ ] Elasticsearch cluster health is yellow or green
- [ ] Nginx accessible at http://localhost:80
- [ ] Kibana accessible at http://localhost:5601
- [ ] Logs appearing in Elasticsearch indices
- [ ] Index pattern created in Kibana
- [ ] Logs visible in Kibana Discover with parsed fields
