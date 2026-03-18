# OMA Lightspeed

AI assistant for OMA Migration Planner, built on the Red Hat Lightspeed Core Stack.

This service provides an intelligent chatbot that helps users analyze migration sources, view assessments, and get recommendations for OpenShift migrations.

## Architecture

```
┌─────────────────┐     ┌─────────────────────┐     ┌─────────────────┐
│     OMA UI      │────▶│   OMA Lightspeed    │────▶│  OMA MCP Server │
│                 │     │ (lightspeed-stack)  │     │  (oma-service)  │
└─────────────────┘     └─────────────────────┘     └─────────────────┘
                                │
                                ▼
                        ┌───────────────┐
                        │  Gemini API   │
                        │  (Vertex AI)  │
                        └───────────────┘
```

**Components:**
- **OMA Lightspeed**: This repository - the AI orchestration layer
- **OMA MCP Server**: Separate service providing migration tools via Model Context Protocol
- **Gemini/Vertex AI**: Google's LLM for natural language understanding

## Quick Start (Local Development)

### Prerequisites

- [Podman](https://podman.io/getting-started/installation) (v4.0+)
- [oc CLI](https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/) (for config generation)
- [yq](https://github.com/mikefarah/yq) (for YAML processing)
- [jq](https://stedolan.github.io/jq/) (for JSON processing)
- [envsubst](https://www.gnu.org/software/gettext/manual/html_node/envsubst-Invocation.html) (usually pre-installed)
- Gemini API key (get one at [Google AI Studio](https://aistudio.google.com/app/apikey))

### Setup

```bash
# 1. Clone the repository
git clone https://github.com/kubev2v/oma-lightspeed.git
cd oma-lightspeed

# 2. Generate configuration (interactive - will ask for API key)
make generate

# 3. Start the services (lightspeed-stack + MCP server)
make run

# 4. Test the API
make query
```

### MCP Server Setup

The pod includes the **oma-service-mcp** container which provides migration tools. By default, it pulls from `quay.io/kubev2v/oma-service-mcp:latest`.

To build locally from the [oma-service-mcp](https://github.com/kubev2v/oma-service-mcp) repo:

```bash
# Clone and build the MCP server
git clone https://github.com/kubev2v/oma-service-mcp.git
cd oma-service-mcp
make build

# Set the image in your .env
echo 'OMA_MCP_IMAGE=localhost/oma-service-mcp:latest' >> ../oma-lightspeed/.env
```

The MCP server needs access to the Migration Planner API. Configure via environment variables in `.env`:

```bash
# URL of your Migration Planner backend (use host.containers.internal to reach host services)
MIGRATION_PLANNER_URL=http://host.containers.internal:3443

# Auth type: 'none' for local dev, 'forwarded' for production
AUTH_TYPE=none
```

### Available Commands

| Command | Description |
|---------|-------------|
| `make generate` | Interactive setup - creates `.env` and config files |
| `make run` | Start the OMA Lightspeed pod |
| `make stop` | Stop the pod (preserves state) |
| `make resume` | Resume a stopped pod |
| `make rm` | Remove the pod completely |
| `make logs` | Follow container logs |
| `make query` | Interactive query interface |
| `make build` | Build the container image |
| `make help` | Show all available commands |

## Configuration

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `GEMINI_API_KEY` | Google Gemini API key | Yes (or Vertex AI) |
| `GOOGLE_APPLICATION_CREDENTIALS` | Path to Vertex AI service account JSON | For Vertex AI |
| `MIGRATION_PLANNER_URL` | URL of the OMA Migration Planner API | No (default: `http://host.containers.internal:3443`) |
| `AUTH_TYPE` | MCP auth type: `none` or `forwarded` | No (default: `none`) |
| `LIGHTSPEED_STACK_IMAGE_OVERRIDE` | Override the lightspeed-stack image | No |
| `OMA_MCP_IMAGE` | Override the MCP server image | No |

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
| MCP Server | Sidecar or external | Separate Service |

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
├── template.yaml              # OpenShift template (source of truth)
├── template-params.dev.env    # Development parameter overrides
├── oma-pod.yaml               # Local development pod spec
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

1. Ensure the OMA MCP server is running
2. Check the MCP URL in `config/lightspeed-stack.yaml`
3. For local dev, uncomment the MCP sidecar in `oma-pod.yaml`

### Database errors in production

1. Verify PostgreSQL secret exists: `oc get secret oma-lightspeed-db`
2. Check migration logs in the container startup
3. Ensure database is accessible from the pod

## License

Apache License 2.0

## Related Projects

- [lightspeed-stack](https://github.com/lightspeed-core/lightspeed-stack) - The core AI orchestration framework
- [assisted-chat](https://github.com/rh-ecosystem-edge/assisted-chat) - Reference implementation for OpenShift Assisted Installer
