# OMA Lightspeed

AI assistant for OMA Migration Planner, built on the Red Hat Lightspeed Core Stack.

This service provides an intelligent chatbot that helps users analyze migration sources, view assessments, and get recommendations for OpenShift migrations.

## Architecture

```
┌─────────────────┐     ┌─────────────────────┐     ┌─────────────────┐
│     OMA UI      │────▶│   OMA Lightspeed    │────▶│  OMA MCP Server │
│                 │     │ (lightspeed-stack)  │     │  (oma-service)  │
└─────────────────┘     └─────────────────────┘     └─────────────────┘
                                │                           │
                                ▼                           ▼
                        ┌───────────────┐          ┌────────────────┐
                        │  Gemini API   │          │  Migration     │
                        │  (Vertex AI)  │          │  Planner API   │
                        └───────────────┘          └────────────────┘
```

**Components:**
- **OMA Lightspeed**: This repository - the AI orchestration layer
- **OMA MCP Server**: Separate service providing migration tools via Model Context Protocol
- **Migration Planner API**: Backend service providing migration data
- **Gemini/Vertex AI**: Google's LLM for natural language understanding

## Quick Start (Local Development)

### Prerequisites

- [Podman](https://podman.io/getting-started/installation) (v4.0+)
- [podman-compose](https://github.com/containers/podman-compose) (`pip install podman-compose`)
- [yq](https://github.com/mikefarah/yq) (for YAML processing)
- [jq](https://stedolan.github.io/jq/) (for JSON processing)
- Gemini API key (get one at [Google AI Studio](https://aistudio.google.com/app/apikey))

### Setup

```bash
# 1. Clone the repository
git clone https://github.com/kubev2v/oma-lightspeed.git
cd oma-lightspeed

# 2. Build the MCP server image (first time only)
git clone https://github.com/kubev2v/oma-service-mcp.git ../oma-service-mcp
make build-mcp

# 3. Generate configuration (interactive - will ask for API key)
make generate

# 4. Start the full stack (PostgreSQL + Planner + MCP + Lightspeed)
make run

# 5. Test the API
make query
```

`make run` starts the complete OMA AI stack:

```
PostgreSQL ──▶ Migration Planner API ──▶ OMA Service MCP ──▶ Lightspeed Stack
  :5432            :3443                    :8000               :8080
```

The Lightspeed API is exposed at **http://localhost:8080**.

### Available Commands

| Command | Description |
|---------|-------------|
| `make generate` | Interactive setup - creates `.env` and config files |
| `make run` | Start the full stack |
| `make stop` | Stop services (preserves data) |
| `make resume` | Resume stopped services |
| `make rm` | Remove services and volumes |
| `make logs` | Follow all logs (or `make logs SERVICE=lightspeed-stack`) |
| `make query` | Interactive query interface |
| `make build` | Build the OMA Lightspeed container image |
| `make build-mcp` | Build the MCP server image from `../oma-service-mcp` |
| `make help` | Show all available commands |

## Configuration

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `GEMINI_API_KEY` | Google Gemini API key | Yes (or Vertex AI) |
| `LIGHTSPEED_STACK_IMAGE` | Override the lightspeed-stack image | No |
| `OMA_MCP_IMAGE` | Override the MCP server image | No (default: `localhost/oma-service-mcp:latest`) |
| `MIGRATION_PLANNER_IMAGE` | Override the migration planner image | No |
| `LIGHTSPEED_PORT` | Host port for the API | No (default: `8080`) |

### Config Files

After running `make generate`, these files are created in `config/`:

- **`lightspeed-stack.yaml`**: Main service configuration (auth, MCP, inference settings)
- **`llama_stack_client_config.yaml`**: LLM provider and agent configuration
- **`systemprompt.txt`**: The AI assistant's persona and behavior rules

### Local vs Production

| Aspect | Local | Production |
|--------|-------|------------|
| Database | SQLite | PostgreSQL |
| Auth | Disabled | Red Hat SSO (JWK) |
| LLM Credentials | `.env` file | Kubernetes Secret (Vault) |
| MCP Server | Compose service | Separate Service |
| Migration Planner | Compose service | Separate Deployment |

## Production Deployment

### OpenShift Template

The `template.yaml` is the source of truth for production deployment. It contains:
- ConfigMaps with embedded configurations
- Deployment with health checks
- Service and Route
- Database migration script

### Deploy to OpenShift

```bash
# Process the template with production parameters
oc process -f template.yaml \
  -p IMAGE_TAG=v1.0.0 \
  -p LIGHTSPEED_SERVICE_AUTH_ENABLED=true \
  -p ROUTE_HOST=oma-lightspeed.apps.example.com \
  | oc apply -f -

# Create required secrets (example)
oc create secret generic oma-lightspeed-db \
  --from-literal=db.host=postgres.example.com \
  --from-literal=db.port=5432 \
  --from-literal=db.name=oma_lightspeed \
  --from-literal=db.user=oma \
  --from-literal=db.password=<password>

oc create secret generic oma-lightspeed-vertex-secret \
  --from-file=service_account=/path/to/service-account.json
```

### Network Policies

Apply the network policy for secure pod communication:

```bash
oc apply -f deploy/networkpolicy.yaml
```

## API Reference

### Health Endpoints

- `GET /liveness` - Liveness probe
- `GET /readiness` - Readiness probe

### Query Endpoint

```bash
curl -X POST http://localhost:8080/v1/query \
  -H "Content-Type: application/json" \
  -d '{"query": "List my migration sources"}'
```

### Streaming Query

```bash
curl -X POST http://localhost:8080/v1/streaming_query \
  -H "Content-Type: application/json" \
  -d '{"query": "Analyze my assessment results"}'
```

## Development

### Building the Image

```bash
# Build locally
make build

# Build with custom tag
podman build -f Containerfile -t oma-lightspeed:dev .
```

### Testing

```bash
# Start the service
make run

# In another terminal, run queries
make query

# Or use curl directly
curl http://localhost:8080/liveness
```

### Updating the System Prompt

Edit the system prompt in `template.yaml` under the `lightspeed-stack-config` ConfigMap, then regenerate:

```bash
make generate
make rm
make run
```

## Project Structure

```
oma-lightspeed/
├── Containerfile              # Container image definition
├── Makefile                   # Developer commands
├── compose.yaml               # Local dev stack (podman-compose)
├── template.yaml              # OpenShift template (source of truth)
├── template-params.dev.env    # Development parameter overrides
├── .env.template              # Environment variable template
├── config/                    # Generated config files (gitignored)
├── scripts/
│   ├── generate.sh            # Config generation script
│   ├── run.sh                 # Start services
│   ├── stop.sh                # Stop services
│   ├── rm.sh                  # Remove services
│   ├── resume.sh              # Resume services
│   ├── logs.sh                # View logs
│   └── query.sh               # Query interface
└── deploy/
    └── networkpolicy.yaml     # Production network policies
```

## Troubleshooting

### Service won't start

1. Check if config files exist: `ls config/`
2. Run `make generate` if they're missing
3. Check logs: `make logs`

### "Gemini API key invalid"

1. Verify your API key at [Google AI Studio](https://aistudio.google.com/)
2. Regenerate config: `rm .env && make generate`

### MCP tools not available

1. Check the MCP server is healthy: `make logs SERVICE=oma-service-mcp`
2. Check the MCP URL in `config/lightspeed-stack.yaml`
3. Verify Migration Planner is reachable: `make logs SERVICE=migration-planner`

### MCP server image not found

Build the image from the sibling repository:

```bash
make build-mcp
```

### Database errors in production

1. Verify PostgreSQL secret exists: `oc get secret oma-lightspeed-db`
2. Check migration logs in the container startup
3. Ensure database is accessible from the pod

## License

Apache License 2.0

## Related Projects

- [lightspeed-stack](https://github.com/lightspeed-core/lightspeed-stack) - The core AI orchestration framework
- [oma-service-mcp](https://github.com/kubev2v/oma-service-mcp) - MCP server providing migration tools
- [migration-planner](https://github.com/kubev2v/migration-planner) - Core SaaS service for migration planning
