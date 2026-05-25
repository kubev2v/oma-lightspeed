# OMA Lightspeed Agent Evaluation

End-to-end evaluation for OMA Lightspeed using [lsc_agent_eval](https://github.com/lightspeed-core/lightspeed-evaluation/tree/main/lsc_agent_eval) — the same framework used by assisted-chat and other Lightspeed Core consumers.

## How It Works

`eval.py` sends queries to a running OMA Lightspeed instance and validates responses using:
- **response_eval:intent** — LLM judge (Gemini) checks if the response conveys the correct intent
- **response_eval:sub-string** — verifies expected keywords appear in the response
- **response_eval:accuracy** — semantic similarity to an expected response
- **tool_eval** — validates the LLM called the correct MCP tools with correct arguments

Test cases are defined in `eval_data.yaml`, organized into conversation groups with tags.

## Prerequisites

- Python 3.11+
- OMA Lightspeed running locally (`make run` from the repo root)
- Gemini API key for the LLM judge: `export GEMINI_API_KEY=...`

Install the eval framework:
```bash
pip install git+https://github.com/lightspeed-core/lightspeed-evaluation.git#subdirectory=lsc_agent_eval
```

## Running Tests

From the repo root:
```bash
make test-eval                     # smoke tests (default)
make test-eval EVAL_TAGS=all       # all tests
make test-eval EVAL_TAGS=domain    # domain knowledge tests only
```

Or directly:
```bash
cd test/evals
python eval.py --tags smoke
python eval.py --tags domain role-protection
python eval.py  # all tests
```

## Test Tags

| Tag | What it tests |
|-----|--------------|
| `smoke` | Core tool calls, greeting, basic guardrails |
| `domain` | Migration domain knowledge (assessment methods, complexity, sizing, blockers) |
| `role-protection` | Off-topic refusal, role-play refusal, tone manipulation |
| `non-disclosure` | System prompt protection, model detail refusal, prompt injection |
| `tool-usage` | Multi-turn tool routing, estimation, complexity, context retention |

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

Smoke tests run in GitHub Actions on PRs (requires `GEMINI_API_KEY` repository secret).
