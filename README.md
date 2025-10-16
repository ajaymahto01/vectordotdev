# Nginx + Vector.dev + Elasticsearch + Kibana Setup

This project demonstrates a complete logging pipeline using Docker containers:
- **Nginx**: Sample web application generating logs
- **Vector.dev**: Log shipper that collects and forwards logs
- **Elasticsearch**: Stores the collected logs
- **Kibana**: Visualizes the logs

## Architecture

```
nginx (generates logs) → Vector (ships logs) → Elasticsearch (stores logs) → Kibana (visualizes logs)
```

## Prerequisites

- Docker
- Docker Compose

## Project Structure

```
.
├── docker-compose.yml          # Docker Compose configuration
├── nginx/
│   ├── nginx.conf             # Nginx configuration with JSON logging
│   └── logs/                  # Nginx log files (mounted volume)
├── vector/
│   └── vector.toml            # Vector configuration for log shipping
└── README.md
```

## Quick Start

1. **Start all services**:
   ```bash
   docker compose up -d
   ```

2. **Verify all services are running**:
   ```bash
   docker compose ps
   ```

3. **Generate some nginx logs** by accessing the nginx server:
   ```bash
   curl http://localhost:8080
   curl http://localhost:8080/health
   ```

4. **Access Kibana** at http://localhost:5601

5. **Configure Kibana** (first time only):
   - Navigate to Management → Stack Management → Data Views
   - Click "Create data view"
   - Enter `nginx-access-*` as the index pattern
   - Select `timestamp` as the time field
   - Click "Save data view to Kibana"

6. **View logs in Kibana**:
   - Navigate to Analytics → Discover
   - Select the `nginx-access-*` data view
   - You should see the nginx access logs with all the parsed fields

For detailed instructions, see [SETUP_GUIDE.md](SETUP_GUIDE.md)

## Service Details

### Nginx
- **Port**: 8080 (mapped to container port 80)
- **Logs**: JSON formatted access logs and standard error logs
- **Configuration**: `nginx/nginx.conf`

### Vector
- **Purpose**: Reads nginx logs and ships them to Elasticsearch
- **Configuration**: `vector/vector.toml`
- **Features**:
  - Parses JSON access logs
  - Processes error logs
  - Creates daily indices in Elasticsearch

### Elasticsearch
- **Port**: 9200
- **Indices**: 
  - `nginx-access-YYYY.MM.DD`: Access logs
  - `nginx-error-YYYY.MM.DD`: Error logs
- **Security**: Disabled for simplicity (not for production!)

### Kibana
- **Port**: 5601
- **Purpose**: Web UI for exploring and visualizing logs

## Useful Commands

### View logs from all services
```bash
docker-compose logs -f
```

### View logs from a specific service
```bash
docker-compose logs -f vector
docker-compose logs -f nginx
```

### Check Elasticsearch indices
```bash
curl http://localhost:9200/_cat/indices?v
```

### Search logs in Elasticsearch
```bash
curl http://localhost:9200/nginx-access-*/_search?pretty
```

### Stop all services
```bash
docker-compose down
```

### Stop and remove volumes
```bash
docker-compose down -v
```

## Testing the Setup

1. Generate traffic to nginx:
   ```bash
   for i in {1..10}; do curl http://localhost:8080; done
   ```

2. Check Vector is processing logs:
   ```bash
   docker-compose logs vector | grep -i "nginx"
   ```

3. Verify logs in Elasticsearch:
   ```bash
   curl -s http://localhost:9200/nginx-access-*/_search?size=5 | jq .
   ```

4. View in Kibana at http://localhost:5601

## Troubleshooting

### Services not starting
- Check if ports 8080, 5601, or 9200 are already in use
- Run `docker-compose logs <service-name>` to see error messages

### No logs in Kibana
- Ensure nginx has been accessed to generate logs
- Check Vector logs: `docker-compose logs vector`
- Verify Elasticsearch has indices: `curl http://localhost:9200/_cat/indices?v`
- Make sure the data view pattern in Kibana matches the index names

### Elasticsearch health issues
- Wait for Elasticsearch to fully start (can take 1-2 minutes)
- Check status: `curl http://localhost:9200/_cluster/health`

## Customization

### Modify nginx log format
Edit `nginx/nginx.conf` and restart nginx:
```bash
docker-compose restart nginx
```

### Change Vector configuration
Edit `vector/vector.toml` and restart Vector:
```bash
docker-compose restart vector
```

### Adjust resource limits
Edit the `ES_JAVA_OPTS` in `docker-compose.yml` to allocate more/less memory to Elasticsearch.

## Clean Up

To remove all containers, networks, and volumes:
```bash
docker-compose down -v
rm -rf nginx/logs/*
```

## Notes

- This setup is for **development/demonstration purposes only**
- Elasticsearch security is disabled for simplicity
- Data is persisted in Docker volumes
- Nginx logs are also available in the `nginx/logs` directory on the host
