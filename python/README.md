# Python Lab — Cloud Resource Processor

## Setup

```bash
cd python
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
```

## Background

Your team has an internal API that returns a JSON inventory of all cloud resources across accounts and regions. You've been handed a snapshot of that data at `data/resources.json` and a starter script that was thrown together quickly to process it.

The script is supposed to:
1. Identify resources missing required tags (`owner`, `environment`, `cost_center`)
2. Identify zombie resources — stopped or terminated and older than 30 days
3. Summarize hourly cost grouped by owner
4. Write a CSV report to `output/report.csv`

**It has bugs. It will crash before it finishes.**

## Your Tasks

### Stage 1 — Fix the bugs (15 min)

Run the script and fix all errors until it produces correct output:

```bash
python processor.py
```

### Stage 2 — Improve the code (15 min)

Once it works:

1. Rename variables and functions so the code is readable without needing to trace every reference
2. Add a `--dry-run` flag that prints the report to stdout instead of writing a file
3. The cost summary currently crashes on some resources — make it handle those gracefully and exclude them from the owner totals

### Stage 3 — Tests (10 min)

Write pytest tests in `tests/test_processor.py` covering:

1. A resource with all required tags passes tag validation
2. A resource missing `owner` is flagged correctly
3. A stopped resource older than 30 days is identified as a zombie
4. A running resource is never flagged as a zombie regardless of age

Run with:
```bash
pytest tests/ -v
```

## Notes

- Use any tools you normally use
- Talk through what you're seeing — we want to understand your process
- If you finish early, consider: what other signals in this data might be worth surfacing?
