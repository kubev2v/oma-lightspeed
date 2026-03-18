#!/bin/bash
# Query the OMA Lightspeed service
#
# Usage:
#   ./query.sh                    # Interactive mode
#   ./query.sh "your question"    # Single query

set -euo pipefail

BASE_URL="${OMA_LIGHTSPEED_URL:-http://localhost:8080}"

# Check if service is running
if ! curl -s "${BASE_URL}/liveness" > /dev/null 2>&1; then
    echo "Error: OMA Lightspeed service is not running at ${BASE_URL}"
    echo "Run 'make run' to start it."
    exit 1
fi

echo "OMA Lightspeed Query Interface"
echo "Service: ${BASE_URL}"
echo "Type 'exit' or 'quit' to exit"
echo ""

# Single query mode
if [[ $# -gt 0 ]]; then
    QUERY="$*"
    echo "Query: $QUERY"
    echo ""

    RESPONSE=$(curl -s -X POST "${BASE_URL}/v1/query" \
        -H "Content-Type: application/json" \
        -d "{\"query\": \"${QUERY}\"}")

    echo "$RESPONSE" | jq -r '.response // .error // .'
    exit 0
fi

# Interactive mode
while true; do
    echo -n "> "
    read -r QUERY

    if [[ "$QUERY" == "exit" || "$QUERY" == "quit" ]]; then
        echo "Goodbye!"
        exit 0
    fi

    if [[ -z "$QUERY" ]]; then
        continue
    fi

    echo ""

    RESPONSE=$(curl -s -X POST "${BASE_URL}/v1/query" \
        -H "Content-Type: application/json" \
        -d "{\"query\": \"${QUERY}\"}")

    echo "$RESPONSE" | jq -r '.response // .error // .'
    echo ""
done
