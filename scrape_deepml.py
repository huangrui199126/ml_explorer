#!/usr/bin/env python3
"""
Scrape deep-ml.com problems via their public API and save to JSON.
Fetches: title, category, difficulty, description, example, learn_section, starter_code
"""

import json
import base64
import time
import sys
import requests
from pathlib import Path

OUTPUT = Path("ios/MLExplorer/Resources/ml_challenges.json")
OUTPUT_ROOT = Path("ml_challenges.json")   # served via GitHub Pages
OUTPUT.parent.mkdir(parents=True, exist_ok=True)

LIST_URL = "https://api.deep-ml.com/list-problems"
FETCH_URL = "https://api.deep-ml.com/fetch-problem?problem_id={}"
DELAY = 0.3  # seconds between requests

def decode(val):
    if not val:
        return ""
    try:
        return base64.b64decode(val).decode("utf-8")
    except Exception:
        return val if isinstance(val, str) else ""

def fetch_all_problems():
    print("Fetching problem list...")
    r = requests.get(LIST_URL, timeout=15)
    r.raise_for_status()
    problems = r.json()["problems"]
    print(f"  {len(problems)} problems found")
    return problems

def fetch_problem_detail(problem_id):
    r = requests.get(FETCH_URL.format(problem_id), timeout=15)
    r.raise_for_status()
    return r.json()

def main():
    # Load existing data to resume if interrupted
    existing = {}
    if OUTPUT.exists():
        with open(OUTPUT) as f:
            data = json.load(f)
            existing = {str(p["id"]): p for p in data.get("problems", [])}
        print(f"Resuming: {len(existing)} problems already scraped")

    problems_meta = fetch_all_problems()

    results = []
    errors = []

    for i, meta in enumerate(problems_meta):
        pid = str(meta["id"])

        # Skip already scraped
        if pid in existing:
            results.append(existing[pid])
            continue

        print(f"[{i+1}/{len(problems_meta)}] #{pid} {meta['title'][:50]}...", end=" ", flush=True)

        try:
            detail = fetch_problem_detail(pid)

            problem = {
                "id": pid,
                "title": meta["title"],
                "category": meta["category"],
                "difficulty": meta["difficulty"],
                "description": decode(detail.get("description", "")),
                "example": detail.get("example", {}),
                "learn_section": decode(detail.get("learn_section", "")),
                "starter_code": detail.get("starter_code", ""),
            }

            results.append(problem)
            existing[pid] = problem
            print("✓")

        except Exception as e:
            print(f"✗ ERROR: {e}")
            errors.append(pid)

        # Save checkpoint every 10 problems
        if (i + 1) % 10 == 0:
            save(results)

        time.sleep(DELAY)

    save(results)
    print(f"\nDone. {len(results)} problems saved. {len(errors)} errors: {errors}")

def save(results):
    # Sort by id numerically
    sorted_results = sorted(results, key=lambda p: int(p["id"]) if p["id"].isdigit() else 9999)

    # Get unique categories
    categories = sorted(set(p["category"] for p in sorted_results))

    output = {
        "total": len(sorted_results),
        "categories": categories,
        "problems": sorted_results
    }
    with open(OUTPUT, "w") as f:
        json.dump(output, f, indent=2, ensure_ascii=False)
    with open(OUTPUT_ROOT, "w") as f:
        json.dump(output, f, indent=2, ensure_ascii=False)
    print(f"  → Saved {len(sorted_results)} problems to {OUTPUT} + {OUTPUT_ROOT}")

if __name__ == "__main__":
    main()
