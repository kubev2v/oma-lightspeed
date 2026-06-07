# OMA Lightspeed Agent Evaluation

End-to-end evaluation for OMA Lightspeed using [lightspeed-evaluation](https://github.com/lightspeed-core/lightspeed-evaluation) — the same framework used by assisted-chat and other Lightspeed Core consumers.

## How It Works

`eval.py` sends queries to a running OMA Lightspeed instance and validates responses using:
- **response_eval:intent** — LLM judge checks if the response conveys the correct intent
- **response_eval:sub-string** — verifies expected keywords appear in the response
- **response_eval:accuracy** — semantic similarity to an expected response
- **tool_eval** — validates the LLM called the correct MCP tools with correct arguments

Test cases are defined in `eval_data.yaml`, organized into conversation groups with tags.

## Prerequisites

- Python 3.11+
- OMA Lightspeed running locally (`make run`) or via Docker Compose
- **LLM judge credentials** (one of):
  - Vertex AI service account: `export GOOGLE_APPLICATION_CREDENTIALS=/path/to/sa.json`
  - Gemini API key: `export GEMINI_API_KEY=...` (use `--judge_provider gemini`)

Install the eval framework:
```bash
pip install git+https://github.com/lightspeed-core/lightspeed-evaluation.git
```

## Running Tests

Against a locally running service (`make run`):
```bash
make test-eval                     # smoke tests (default)
make test-eval EVAL_TAGS=all       # all tests
make test-eval EVAL_TAGS=domain    # domain knowledge tests only
```

Or using Docker Compose (same setup as CI):
```bash
make generate
docker compose -f docker-compose.ci.yaml up -d
make test-eval
docker compose -f docker-compose.ci.yaml down -v
```

## Test Tags

| Tag | What it tests |
|-----|--------------|
| `smoke` | Greeting, capabilities, off-topic refusal, non-disclosure |
| `domain` | Migration domain knowledge (assessment methods, complexity, sizing, blockers) |
| `role-protection` | Off-topic refusal, role-play refusal, tone manipulation |
| `non-disclosure` | System prompt protection, model detail refusal, prompt injection |
| `tool-usage` | MCP tool routing, estimation, complexity, context retention |

## Adding New Tests

Add entries to `eval_data.yaml` following the existing patterns. Each entry needs:
- `conversation_group` — unique group name
- `tags` — list of tags for filtering
- `conversation` — list of eval steps, each with:
  - `eval_id` — unique ID
  - `eval_query` — the user message
  - `eval_types` — list of evaluation methods
  - Type-specific fields: `expected_intent`, `expected_keywords`, `expected_tool_calls`, etc.

## CI

Smoke evals run in GitHub Actions on every PR via Docker Compose:
1. Starts lightspeed-stack + MCP stub containers
2. Sends queries to the live service
3. Uses Vertex AI as the LLM judge to evaluate response quality
4. Blocks merge on eval failure

**Required secret:** `VERTEX_SA_JSON` — Google Cloud service account JSON with Vertex AI access.
Set via: `gh secret set VERTEX_SA_JSON --repo kubev2v/oma-lightspeed < sa.json`
