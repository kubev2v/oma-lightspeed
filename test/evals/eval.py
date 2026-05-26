"""OMA Migration Planner agent goal evaluation."""

import argparse
import logging
import sys
import yaml
import tempfile

from lsc_agent_eval import AgentGoalEval

logging.basicConfig(
    level=logging.WARNING,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)

logging.getLogger("lsc_agent_eval").setLevel(logging.INFO)


def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description="OMA agent goal evaluation")

    parser.add_argument(
        "--eval_data_yaml",
        default="eval_data.yaml",
        help="Path to evaluation data YAML file (default: eval_data.yaml)",
    )

    parser.add_argument(
        "--agent_endpoint",
        default="http://localhost:8080",
        help="Agent endpoint URL (default: http://localhost:8080)",
    )

    parser.add_argument(
        "--endpoint_type",
        choices=["streaming", "query"],
        default="streaming",
        help="Endpoint type (default: streaming)",
    )

    parser.add_argument(
        "--agent_provider",
        default="gemini",
        help="Agent provider (default: gemini)",
    )

    parser.add_argument(
        "--agent_model",
        default="models/gemini-2.5-flash",
        help="Agent model (default: models/gemini-2.5-flash)",
    )

    parser.add_argument(
        "--judge_provider",
        default="vertex",
        help="Judge provider for LLM evaluation (default: vertex)",
    )

    parser.add_argument(
        "--judge_model",
        default="gemini-2.5-flash",
        help="Judge model for LLM evaluation (default: gemini-2.5-flash)",
    )

    parser.add_argument(
        "--agent_auth_token_file",
        default="",
        help="Path to agent auth token file (not required for OMA)",
    )

    parser.add_argument(
        "--result_dir",
        default="eval_output",
        help="Directory for evaluation results (default: eval_output)",
    )

    parser.add_argument(
        "--tags",
        nargs="+",
        default=None,
        help=(
            "Filter tests by tags. If not provided, all tests run. "
            "Available tags: "
            "'smoke' - Core functionality and tool call verification. "
            "'domain' - Migration domain knowledge tests. "
            "'role-protection' - Off-topic, role-play, and tone refusal. "
            "'non-disclosure' - System prompt and config protection. "
            "'tool-usage' - Multi-turn tool routing and parameter passing."
        ),
    )

    return parser.parse_args()


def filter_by_tags(path, tags):
    """Filter YAML data by tags, return path to filtered file."""
    if not tags:
        return path
    with open(path) as f:
        data = [
            g
            for g in yaml.safe_load(f)
            if any(t in g.get("tags", []) for t in tags)
        ]
    if not data:
        sys.exit(f"No tests found with tags: {tags}")
    print(f"Running {len(data)} test group(s) with tags: {tags}")
    tmp = tempfile.NamedTemporaryFile(mode="w", suffix=".yaml", delete=False)
    yaml.dump(data, tmp, default_flow_style=False, sort_keys=False)
    tmp.close()
    return tmp.name


args = parse_args()
args.eval_data_yaml = filter_by_tags(args.eval_data_yaml, args.tags)

evaluator = AgentGoalEval(args)
evaluator.run_evaluation()
result_summary = evaluator.get_result_summary()

failed_evals_count = result_summary["FAIL"] + result_summary["ERROR"]
if failed_evals_count:
    print(f"{failed_evals_count} evaluation(s) failed!")
    sys.exit(1)

print("All evaluations passed!")
sys.exit(0)
