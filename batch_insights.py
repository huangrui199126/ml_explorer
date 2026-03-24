#!/usr/bin/env python3
"""
Batch inference: generate fast + deep insights for all papers in papers.json.
Saves each insight as insights/{key}.json, then git pushes in batches.

Usage:
    export ANTHROPIC_API_KEY=sk-ant-...
    python3 batch_insights.py

For cron (weekly new papers only):
    python3 batch_insights.py --new-only
"""

import argparse
import asyncio
import hashlib
import json
import os
import re
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path


# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

REPO_ROOT    = Path(__file__).parent
PAPERS_JSON  = REPO_ROOT / "papers.json"
INSIGHTS_DIR = REPO_ROOT / "insights"
INDEX_FILE   = INSIGHTS_DIR / "index.json"   # key → subfolder name
CLAUDE_BIN   = os.path.expanduser("~/.local/bin/claude")

BATCH_SIZE   = 500   # max files per subfolder

CONCURRENCY  = 1       # one at a time — steady, no hammering
COMMIT_EVERY = 10      # push every 10 papers so users get insights quickly
DELAY_SECS   = 45      # pause between papers to stay well under rate limits

# ---------------------------------------------------------------------------
# Paper key (matches iOS InsightService.paperKey logic)
# ---------------------------------------------------------------------------

def paper_key(paper: dict) -> str:
    url = paper.get("url", "")
    m = re.search(r"\d{4}\.\d{4,5}", url)
    if m:
        return "arxiv_" + m.group().replace(".", "_")
    h = hashlib.sha256(paper["title"].encode()).digest()
    return "paper_" + "".join(f"{b:02x}" for b in h[:8])

# ---------------------------------------------------------------------------
# Claude CLI call (uses your Claude subscription, no API key needed)
# ---------------------------------------------------------------------------

def call_claude_sync(prompt: str, retries: int = 3) -> str:
    last_err = ""
    for attempt in range(retries):
        try:
            result = subprocess.run(
                [CLAUDE_BIN, "--print", prompt],
                capture_output=True, text=True, timeout=120,
                stdin=subprocess.DEVNULL,
            )
            if result.returncode == 0 and result.stdout.strip():
                return result.stdout.strip()
            # Capture actual error for logging
            last_err = (result.stderr or result.stdout or "no output").strip()[:200]
            # Detect rate limit — back off longer
            if any(k in last_err.lower() for k in ("rate limit", "too many", "429", "overloaded")):
                wait = 60 * (attempt + 1)
                print(f"    rate-limited, waiting {wait}s …", flush=True)
                time.sleep(wait)
            elif attempt < retries - 1:
                time.sleep(10 * (attempt + 1))
        except subprocess.TimeoutExpired:
            last_err = "timeout after 120s"
            print(f"    attempt {attempt+1} timed out", flush=True)
            if attempt < retries - 1:
                time.sleep(15)
        except Exception as e:
            last_err = str(e)
            if attempt < retries - 1:
                time.sleep(10)
    raise RuntimeError(f"claude CLI failed after {retries} retries — last error: {last_err}")

# ---------------------------------------------------------------------------
# JSON extraction (handles markdown fences)
# ---------------------------------------------------------------------------

def extract_json(text: str) -> dict:
    clean = text.strip()
    if clean.startswith("```"):
        lines = clean.split("\n")
        clean = "\n".join(lines[1:]).replace("```", "").strip()
    start = clean.find("{")
    end   = clean.rfind("}")
    if start != -1 and end != -1:
        clean = clean[start:end+1]
    return json.loads(clean)

# ---------------------------------------------------------------------------
# Insight generators
# ---------------------------------------------------------------------------

async def generate_fast(paper: dict, loop) -> dict:
    prompt = f"""Analyze this ML paper. Return ONLY valid JSON — no markdown, no explanation.

Title: {paper['title']}
Authors: {", ".join(paper.get("authors", [])[:5])}
Topic: {paper.get("topic", "Machine Learning")}
Abstract: {paper.get("abstract") or "No abstract available."}

Return exactly:
{{
  "summary": "1-2 sentence plain English summary",
  "key_idea": "The core technical intuition in one sentence",
  "why_it_matters": "Why practitioners should care",
  "possible_use_cases": ["use case 1", "use case 2", "use case 3"]
}}"""
    text = await loop.run_in_executor(None, call_claude_sync, prompt)
    raw  = extract_json(text)
    return {
        "summary":            raw["summary"],
        "key_idea":           raw["key_idea"],
        "why_it_matters":     raw["why_it_matters"],
        "possible_use_cases": raw["possible_use_cases"],
        "generated_at":       datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }


async def generate_deep(paper: dict, loop) -> dict:
    context = paper.get("abstract") or "No content available."
    prompt = f"""You are an expert ML researcher. Analyze this paper deeply.
Return ONLY valid JSON — no markdown, no explanation.

Title: {paper['title']}
Topic: {paper.get("topic", "ML")}

Abstract:
{context[:4000]}

Return exactly:
{{
  "method_breakdown": "How the method works technically — 2-3 sentences",
  "key_innovation": "What is genuinely new vs prior work",
  "technical_insight": "The most important design choice and why it works",
  "limitations": "Main limitations or failure cases",
  "interview_questions": ["Q1?", "Q2?", "Q3?", "Q4?", "Q5?"],
  "interview_answers": ["A1", "A2", "A3", "A4", "A5"]
}}"""
    text = await loop.run_in_executor(None, call_claude_sync, prompt)
    raw  = extract_json(text)
    return {
        "method_breakdown":    raw["method_breakdown"],
        "key_innovation":      raw["key_innovation"],
        "technical_insight":   raw["technical_insight"],
        "limitations":         raw["limitations"],
        "interview_questions": raw["interview_questions"],
        "interview_answers":   raw["interview_answers"],
        "generated_at":        datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }

# ---------------------------------------------------------------------------
# Process one paper
# ---------------------------------------------------------------------------

sem = None  # set in main

def insight_path(key: str, index: dict) -> Path:
    """Return the path where an insight file should be written.
    If key is already in the index, use the recorded subfolder.
    Otherwise, find the first batch folder with room, or create a new one.
    """
    if key in index:
        return INSIGHTS_DIR / index[key] / f"{key}.json"
    # Find a batch folder with fewer than BATCH_SIZE files
    n = 1
    while True:
        folder = INSIGHTS_DIR / f"batch_{n:03d}"
        folder.mkdir(exist_ok=True)
        if len(list(folder.glob("*.json"))) < BATCH_SIZE:
            return folder / f"{key}.json"
        n += 1


def rebuild_index() -> dict:
    """Scan all batch_* subfolders and return key → subfolder mapping."""
    index: dict = {}
    for folder in sorted(INSIGHTS_DIR.glob("batch_*")):
        if folder.is_dir():
            for f in folder.glob("*.json"):
                index[f.stem] = folder.name
    return index


async def process_paper(paper: dict, idx: int, total: int, loop, index: dict) -> bool:
    key  = paper_key(paper)

    # Check if already done (in index or anywhere in subfolders)
    if key in index:
        return False
    # Also check legacy root location
    if (INSIGHTS_DIR / f"{key}.json").exists():
        return False

    async with sem:
        pct = (idx + 1) / total * 100
        try:
            # Hard wall-clock timeout per paper: 5 minutes
            fast = await asyncio.wait_for(generate_fast(paper, loop), timeout=300)
            deep = await asyncio.wait_for(generate_deep(paper, loop), timeout=300)
            insight = {"fast": fast, "deep": deep}
            path = insight_path(key, index)
            path.parent.mkdir(exist_ok=True)
            path.write_text(json.dumps(insight, ensure_ascii=False, indent=2))
            index[key] = path.parent.name   # update in-memory index
            print(f"[{idx+1}/{total} {pct:.1f}%] {key}  ✓  ({path.parent.name})", flush=True)
            return True
        except asyncio.TimeoutError:
            print(f"[{idx+1}/{total} {pct:.1f}%] {key}  SKIP (paper-level timeout >5min)", flush=True)
            return False
        except Exception as e:
            print(f"[{idx+1}/{total} {pct:.1f}%] {key}  SKIP ({e})", flush=True)
            return False
        finally:
            await asyncio.sleep(DELAY_SECS)

# ---------------------------------------------------------------------------
# Git helpers
# ---------------------------------------------------------------------------

def git_commit_push(msg: str):
    try:
        subprocess.run(["git", "-C", str(REPO_ROOT), "add", "insights/"],
                       check=True, capture_output=True)
        result = subprocess.run(
            ["git", "-C", str(REPO_ROOT), "diff", "--cached", "--quiet"],
            capture_output=True)
        if result.returncode == 0:
            return  # nothing staged
        subprocess.run(["git", "-C", str(REPO_ROOT), "commit", "-m", msg],
                       check=True, capture_output=True)
        subprocess.run(["git", "-C", str(REPO_ROOT), "push"],
                       check=True, capture_output=True)
        print(f"  → git pushed: {msg}")
    except subprocess.CalledProcessError as e:
        print(f"  git error: {e.stderr.decode()[:200]}")

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

async def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--new-only", action="store_true",
                        help="Only process papers added in the last 14 days")
    parser.add_argument("--dry-run", action="store_true",
                        help="Print what would be done, don't call API")
    parser.add_argument("--limit", type=int, default=0,
                        help="Max papers to process this run (0 = unlimited, for sliding-window rate limits)")
    args = parser.parse_args()

    if not Path(CLAUDE_BIN).exists():
        print(f"ERROR: claude CLI not found at {CLAUDE_BIN}")
        sys.exit(1)

    INSIGHTS_DIR.mkdir(exist_ok=True)
    papers = json.loads(PAPERS_JSON.read_text())

    if args.new_only:
        from datetime import timedelta
        cutoff = (datetime.now(timezone.utc) - timedelta(days=14)).strftime("%Y-%m-%d")
        papers = [p for p in papers if (p.get("date") or "") >= cutoff]
        print(f"--new-only: {len(papers)} papers added since {cutoff}")

    # Build index of already-done keys (scans all batch_* subfolders)
    index = rebuild_index()
    # Also pick up any legacy root-level files
    for f in INSIGHTS_DIR.glob("*.json"):
        if f.name != "index.json" and f.stem not in index:
            index[f.stem] = "."   # root level (legacy)

    done_keys = set(index.keys())
    todo = [p for p in papers if paper_key(p) not in done_keys]
    print(f"Total: {len(papers)} papers | Already done: {len(done_keys)} | To do: {len(todo)}")

    if args.limit > 0 and len(todo) > args.limit:
        print(f"--limit {args.limit}: capping this run to {args.limit} papers (sliding-window rate limit)")
        todo = todo[:args.limit]

    if not todo:
        print("Nothing to do.")
        return

    if args.dry_run:
        for p in todo[:10]:
            print(f"  would generate: {paper_key(p)}  ({p['title'][:60]})")
        print(f"  ... and {len(todo)-10} more" if len(todo) > 10 else "")
        return

    print(f"Using claude CLI at {CLAUDE_BIN} (your Claude subscription)")
    print(f"Concurrency: {CONCURRENCY}  |  Commit every: {COMMIT_EVERY}")
    print()

    global sem
    sem  = asyncio.Semaphore(CONCURRENCY)
    loop = asyncio.get_event_loop()

    newly_done = 0
    skipped    = 0
    tasks = []

    for idx, paper in enumerate(todo):
        tasks.append(process_paper(paper, idx, len(todo), loop, index))

    # Run in chunks to allow periodic commits
    chunk = COMMIT_EVERY
    for i in range(0, len(tasks), chunk):
        results = await asyncio.gather(*tasks[i:i+chunk])
        n = sum(results)
        newly_done += n
        skipped    += sum(1 for r in results if r is False)
        if n > 0:
            # Write updated index
            INDEX_FILE.write_text(json.dumps(index, ensure_ascii=False, sort_keys=True))
            start_num = i + 1
            end_num   = min(i + chunk, len(todo))
            git_commit_push(f"feat: batch insights {start_num}–{end_num} of {len(todo)}")

    print(f"\nDone. Generated {newly_done} new insights, skipped {skipped} (failures/timeouts).")
    if skipped:
        print("Re-run the script to retry skipped papers.")

if __name__ == "__main__":
    asyncio.run(main())
