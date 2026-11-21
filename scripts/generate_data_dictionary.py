"""
Generate docs/data_dictionary.md from dbt's own metadata.

The descriptions and tests already live in the YAML files, so instead of
maintaining a second, hand-written dictionary that drifts out of date, this
script reads dbt's manifest and writes a Markdown dictionary for every mart.

Run after `dbt parse` (or any dbt command), from the project root:
    python scripts/generate_data_dictionary.py
"""

import json
from collections import defaultdict
from pathlib import Path

MANIFEST = Path("target/manifest.json")
OUTPUT = Path("docs/data_dictionary.md")


def one_line(text: str) -> str:
    """Make a description safe for one Markdown table cell."""
    return " ".join((text or "").split()).replace("|", "\\|")


def main() -> None:
    manifest = json.loads(MANIFEST.read_text())
    nodes = manifest["nodes"]

    # Which tests apply to which model column: {(model_id, column): [test names]}
    tests_by_column = defaultdict(list)
    for node in nodes.values():
        if node["resource_type"] != "test":
            continue
        column = node.get("column_name")
        meta = node.get("test_metadata") or {}
        if column and meta.get("name"):
            for parent in node["depends_on"]["nodes"]:
                tests_by_column[(parent, column)].append(meta["name"])

    marts = sorted(
        (n for n in nodes.values()
         if n["resource_type"] == "model" and "/marts/" in "/" + n["original_file_path"]),
        key=lambda n: (not n["name"].startswith("fct_"), n["name"]),
    )

    lines = [
        "# Data dictionary",
        "",
        "Generated from dbt metadata by `scripts/generate_data_dictionary.py`. Don't edit by hand:",
        "change the descriptions in the model YAML files and re-run the script.",
        "",
        "| Model | Materialization | Description |",
        "| --- | --- | --- |",
    ]
    for model in marts:
        lines.append(
            f"| [`{model['name']}`](#{model['name']}) | {model['config']['materialized']} "
            f"| {one_line(model['description'])} |"
        )

    for model in marts:
        contract = model["config"].get("contract", {}).get("enforced", False)
        owner = model["config"].get("meta", {}).get("owner", "")
        lines += ["", f"## {model['name']}", "", one_line(model["description"]), ""]
        details = [f"Materialization: `{model['config']['materialized']}`"]
        if owner:
            details.append(f"Owner: `{owner}`")
        if contract:
            details.append("Contract: **enforced**")
        lines += [" · ".join(details), "", "| Column | Description | Tests |", "| --- | --- | --- |"]
        for name, column in model["columns"].items():
            tests = ", ".join(sorted(set(tests_by_column[(model["unique_id"], name)])))
            type_note = f" `{column['data_type']}`" if column.get("data_type") else ""
            lines.append(f"| `{name}`{type_note} | {one_line(column['description'])} | {tests} |")

    OUTPUT.parent.mkdir(exist_ok=True)
    OUTPUT.write_text("\n".join(lines) + "\n")
    print(f"Wrote {OUTPUT} ({len(marts)} models)")


if __name__ == "__main__":
    main()