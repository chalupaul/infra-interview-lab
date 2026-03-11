"""
Resource inventory processor.

Loads a cloud resource inventory from a JSON file and produces:
  - a list of untagged or under-tagged resources
  - a list of zombie resources (stopped/terminated and older than 30 days)
  - a cost summary grouped by owner
  - a CSV report written to output/report.csv
"""

import json
import csv
import os
from datetime import datetime, timezone


REQUIRED_TAGS = ["owner", "environment", "cost_center"]
REPORT_PATH = "output/report.csv"
STALE_DAYS = 30


def load(f):
    with open(f) as f:
        d = json.load(f)
    return d["resources"]


def check_tags(r):
    t = r["tags"]
    missing = []
    for tag in REQUIRED_TAGS:
        if tag not in t:
            missing.append(tag)
    return missing


def is_zombie(r, now):
    if r["state"] not in ("stopped", "terminated"):
        return False
    l = datetime.fromisoformat(r["launched_at"].replace("Z", "+00:00"))
    delta = (now - l).days
    return delta > STALE_DAYS


def get_cost(resources):
    totals = {}
    for r in resources:
        owner = r["tags"]["owner"]
        totals[owner] = totals.get(owner, 0) + r["cost_per_hour"]
    return totals


def make_report(resources, bad_tags, zombies):
    os.makedirs("output", exist_ok=True)
    with open(REPORT_PATH, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["id", "name", "type", "state", "region", "cost_per_hour", "issues"])
        for r in resources:
            issues = []
            if r["id"] in bad_tags:
                issues.append("missing_tags:" + ",".join(bad_tags[r["id"]]))
            if r["id"] in zombies:
                issues.append("zombie")
            w.writerow([
                r["id"],
                r["name"],
                r["type"],
                r["state"],
                r["region"],
                r["cost_per_hour"],
                "; ".join(issues) if issues else "ok"
            ])


def main():
    resources = load("data/resources.json")
    now = datetime.now(timezone.utc)

    bad_tags = {}
    for r in resources:
        missing = check_tags(r)
        if missing:
            bad_tags[r["id"]] = missing

    zombies = []
    for r in resources:
        if is_zombie(r, now):
            zombies.append(r["id"])

    costs = get_cost(resources)

    print(f"\n=== Tag Violations ({len(bad_tags)}) ===")
    for id, missing in bad_tags.items():
        print(f"  {id}: missing {missing}")

    print(f"\n=== Zombie Resources ({len(zombies)}) ===")
    for id in zombies:
        print(f"  {id}")

    print(f"\n=== Cost by Owner ===")
    for owner, total in sorted(costs.items(), key=lambda x: x[1], reverse=True):
        print(f"  {owner}: ${total:.4f}/hr")

    make_report(resources, bad_tags, zombies)
    print(f"\nReport written to {REPORT_PATH}")


if __name__ == "__main__":
    main()
