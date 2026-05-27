#!/bin/bash
# Generate configuration files for local development
#
# This script:
# 1. Creates .env file with API credentials (interactive setup)
# 2. Extracts the system prompt from template.yaml
# 3. Writes lightspeed-stack.yaml and llama_stack_client_config.yaml
#    with SQLite config for local dev (template.yaml uses PostgreSQL)

set -euo pipefail

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")

# Interactive .env setup
if [[ ! -f "$PROJECT_ROOT/.env" ]]; then
    if [[ ! -t 0 ]]; then
        echo "Error: .env file not found and stdin is not interactive."
        echo "Create .env manually before running in CI/non-interactive mode:"
        echo "  echo 'GEMINI_API_KEY=your-key' > .env"
        exit 1
    fi
    echo "Missing .env file. Let's set it up."
    echo ""
    echo "How do you want to authenticate with Google AI?"
    echo "  g) Gemini API Key (simpler, recommended for local dev)"
    echo "  v) Vertex AI Service Account (production-like)"
    read -rp "Choose [g/v]: " auth_type

    if [[ "$auth_type" == "g" || "$auth_type" == "G" ]]; then
        echo ""
        echo "Get your Gemini API key from: https://console.cloud.google.com/apis/credentials"
        read -rsp "Enter your Gemini API Key: " GEMINI_API_KEY
        echo ""

        echo "GEMINI_API_KEY=$GEMINI_API_KEY" > "$PROJECT_ROOT/.env"
        chmod 600 "$PROJECT_ROOT/.env"
        echo "Gemini API key saved to .env"

        # Create dummy Vertex credentials file
        if [[ ! -f "$PROJECT_ROOT/config/vertex-credentials.json" ]]; then
            echo '{}' > "$PROJECT_ROOT/config/vertex-credentials.json"
            chmod 600 "$PROJECT_ROOT/config/vertex-credentials.json"
        fi

    elif [[ "$auth_type" == "v" || "$auth_type" == "V" ]]; then
        echo ""
        read -rp "Enter path to your Vertex AI service account JSON file: " VERTEX_PATH

        if [[ ! -f "$VERTEX_PATH" ]]; then
            echo "Error: File not found: $VERTEX_PATH"
            exit 1
        fi

        cp "$VERTEX_PATH" "$PROJECT_ROOT/config/vertex-credentials.json"
        chmod 600 "$PROJECT_ROOT/config/vertex-credentials.json"

        read -rp "Enter your GCP project ID: " VERTEXAI_PROJECT
        read -rp "Enter your GCP region [us-central1]: " VERTEXAI_LOCATION
        VERTEXAI_LOCATION="${VERTEXAI_LOCATION:-us-central1}"

        # Set dummy API key (Vertex AI doesn't use it, but config expects it)
        cat > "$PROJECT_ROOT/.env" <<ENVEOF
GEMINI_API_KEY=dummy
VERTEXAI_PROJECT=$VERTEXAI_PROJECT
VERTEXAI_LOCATION=$VERTEXAI_LOCATION
ENVEOF
        chmod 600 "$PROJECT_ROOT/.env"
        echo "Vertex AI credentials configured."

    else
        echo "Invalid choice. Exiting."
        exit 1
    fi
else
    echo ".env file already exists. Skipping interactive setup."
fi

# Source environment
source "$PROJECT_ROOT/.env"

# Ensure config directory exists
mkdir -p "$PROJECT_ROOT/config"

# Check for yq command (used to extract system prompt from template)
if ! command -v yq &> /dev/null; then
    echo "Error: 'yq' command not found."
    echo "Install it: brew install yq (macOS) or https://github.com/mikefarah/yq"
    exit 1
fi

# Generate system prompt from template (the only config extracted from template.yaml;
# lightspeed-stack.yaml and llama_stack_client_config.yaml are written directly below
# with SQLite settings since the template uses PostgreSQL for production)
echo "Generating config/systemprompt.txt..."
yq -r '.objects[] | select(.metadata.name == "lightspeed-stack-config") | .data.system_prompt' \
    "$PROJECT_ROOT/template.yaml" \
    > "$PROJECT_ROOT/config/systemprompt.txt"

# Write lightspeed-stack.yaml and llama_stack_client_config.yaml with SQLite config.
# The pod (oma-pod.yaml) mounts a persistent volume at /data and sets
# SQLITE_STORE_DIR=/data, so all db_path values use /data to stay consistent.
echo "Generating config/lightspeed-stack.yaml..."
cat > "$PROJECT_ROOT/config/lightspeed-stack.yaml" << 'EOF'
name: oma-lightspeed
service:
  host: 0.0.0.0
  port: 8080
  auth_enabled: false
  workers: 1
  color_log: true
  access_log: true
llama_stack:
  use_as_library_client: true
  library_client_config_path: "llama_stack_client_config.yaml"
mcp_servers:
  - name: mcp::oma
    url: "http://localhost:8000/mcp"
user_data_collection:
  feedback_enabled: false
  transcripts_enabled: false
customization:
  system_prompt_path: "/tmp/systemprompt.txt"
  disable_query_system_prompt: false
inference:
  default_model: models/gemini-2.5-flash
  default_provider: gemini
database:
  sqlite:
    db_path: /data/lightspeed-stack.db
conversation_cache:
  type: sqlite
  sqlite:
    db_path: /data/conversation_cache.db
EOF

echo "Generating config/llama_stack_client_config.yaml..."
cat > "$PROJECT_ROOT/config/llama_stack_client_config.yaml" << 'EOF'
version: 2
image_name: starter
apis:
- agents
- files
- inference
- safety
- tool_runtime
- vector_io
providers:
  inference:
  - provider_id: gemini
    provider_type: remote::gemini
    config:
      api_key: ${env.GEMINI_API_KEY:=}
  vector_io:
  - provider_id: faiss
    provider_type: inline::faiss
    config:
      kvstore:
        type: sqlite
        namespace: null
        db_path: ${env.SQLITE_STORE_DIR:=/data}/faiss_store.db
      persistence:
        namespace: faiss
        backend: kv_default
  files:
  - provider_id: meta-reference
    provider_type: inline::localfs
    config:
      storage_dir: ${env.SQLITE_STORE_DIR:=/data}/files
      metadata_store:
        table_name: files_metadata
        backend: sql_default
  safety: []
  agents:
  - provider_id: meta-reference
    provider_type: inline::meta-reference
    config:
      persistence:
        agent_state:
          namespace: agents
          backend: kv_default
        responses:
          table_name: responses
          backend: sql_default
  tool_runtime:
  - provider_id: model-context-protocol
    provider_type: remote::model-context-protocol
    config: {}
metadata_store:
  type: sqlite
  db_path: ${env.SQLITE_STORE_DIR:=/data}/registry.db
inference_store:
  type: sqlite
  db_path: ${env.SQLITE_STORE_DIR:=/data}/inference_store.db
registered_resources:
  models:
  - metadata: {}
    model_id: gemini-2.5-flash
    provider_id: gemini
    provider_model_id: models/gemini-2.5-flash
  shields: []
  datasets: []
  scoring_fns: []
  benchmarks: []
  tool_groups:
  - toolgroup_id: mcp::oma
    provider_id: model-context-protocol
    mcp_endpoint:
      uri: "http://localhost:8000/mcp"
server:
  port: 8321
EOF

echo ""
echo "Configuration generated successfully!"
echo ""
echo "Files created:"
echo "  config/lightspeed-stack.yaml"
echo "  config/llama_stack_client_config.yaml"
echo "  config/systemprompt.txt"
echo ""
echo "Next step: run 'make run' to start the services"
