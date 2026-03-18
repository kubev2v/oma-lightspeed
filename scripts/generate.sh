#!/bin/bash
# Generate configuration files from template.yaml for local development
#
# This script:
# 1. Creates .env file with Gemini API key (interactive setup)
# 2. Processes template.yaml with dev parameters
# 3. Extracts config files into config/ directory

set -euo pipefail

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")

# Interactive .env setup
if [[ ! -f "$PROJECT_ROOT/.env" ]]; then
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

        # Set dummy API key (Vertex AI doesn't use it, but config expects it)
        echo "GEMINI_API_KEY=dummy" > "$PROJECT_ROOT/.env"
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

# Check for oc command
if ! command -v oc &> /dev/null; then
    echo "Error: 'oc' command not found."
    echo "Install it from: https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/"
    echo "Or use 'brew install openshift-cli' on macOS"
    exit 1
fi

# Generate lightspeed-stack.yaml from template
echo "Generating config/lightspeed-stack.yaml..."
oc process --local \
    -f "$PROJECT_ROOT/template.yaml" \
    --param-file="$PROJECT_ROOT/template-params.dev.env" \
    | yq '.items[] | select(.kind == "ConfigMap" and .metadata.name == "lightspeed-stack-config").data."lightspeed-stack.yaml"' -r \
    > "$PROJECT_ROOT/config/lightspeed-stack.yaml"

# Generate llama_stack_client_config.yaml from template
echo "Generating config/llama_stack_client_config.yaml..."
oc process --local \
    -f "$PROJECT_ROOT/template.yaml" \
    --param-file="$PROJECT_ROOT/template-params.dev.env" \
    | yq '.items[] | select(.kind == "ConfigMap" and .metadata.name == "llama-stack-client-config").data."llama_stack_client_config.yaml"' -r \
    > "$PROJECT_ROOT/config/llama_stack_client_config.yaml"

# Generate system prompt from template
echo "Generating config/systemprompt.txt..."
yq -r '.objects[] | select(.metadata.name == "lightspeed-stack-config") | .data.system_prompt' \
    "$PROJECT_ROOT/template.yaml" \
    > "$PROJECT_ROOT/config/systemprompt.txt"

# Post-process: Replace postgres config with sqlite for local dev
echo "Adjusting config for SQLite (local dev)..."

# Update lightspeed-stack.yaml to use SQLite instead of PostgreSQL
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
  default_model: gemini-2.5-flash
  default_provider: gemini
database:
  sqlite:
    db_path: /tmp/sqlite/lightspeed-stack.db
conversation_cache:
  type: sqlite
  sqlite:
    db_path: /tmp/sqlite/conversation_cache.db
EOF

# Update llama_stack_client_config.yaml for SQLite
cat > "$PROJECT_ROOT/config/llama_stack_client_config.yaml" << 'EOF'
version: 2
image_name: starter
apis:
- agents
- inference
- safety
- telemetry
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
        db_path: ${env.SQLITE_STORE_DIR:=/tmp/sqlite}/faiss_store.db
  safety: []
  agents:
  - provider_id: meta-reference
    provider_type: inline::meta-reference
    config:
      persistence_store:
        type: sqlite
        db_path: ${env.SQLITE_STORE_DIR:=/tmp/sqlite}/agents_store.db
      responses_store:
        type: sqlite
        db_path: ${env.SQLITE_STORE_DIR:=/tmp/sqlite}/responses_store.db
  telemetry:
  - provider_id: meta-reference
    provider_type: inline::meta-reference
    config:
      service_name: "oma-lightspeed"
      sinks: console,sqlite
      sqlite_db_path: ${env.SQLITE_STORE_DIR:=/tmp/sqlite}/trace_store.db
  tool_runtime:
  - provider_id: model-context-protocol
    provider_type: remote::model-context-protocol
    config: {}
metadata_store:
  type: sqlite
  db_path: ${env.SQLITE_STORE_DIR:=/tmp/sqlite}/registry.db
inference_store:
  type: sqlite
  db_path: ${env.SQLITE_STORE_DIR:=/tmp/sqlite}/inference_store.db
models: []
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
