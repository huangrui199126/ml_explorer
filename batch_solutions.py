#!/usr/bin/env python3
"""
Batch generate code solutions for all ML challenges.
Outputs: solutions/{id}.json for each problem → served via GitHub Pages.

Usage:
    python3 batch_solutions.py            # all problems
    python3 batch_solutions.py --start 1  # resume from problem id

Each solutions/{id}.json:
{
  "id": "1",
  "python":     {"code": "...", "explanation": "...", "key_learnings": ["..."]},
  "numpy":      {"code": "...", "explanation": "...", "key_learnings": ["..."]} or null,
  "tensorflow": ... or null,
  "pytorch":    ... or null
}
"""

import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path

REPO_ROOT      = Path(__file__).parent
CHALLENGES_JSON = REPO_ROOT / "ml_challenges.json"
SOLUTIONS_DIR  = REPO_ROOT / "solutions"
CLAUDE_BIN     = os.path.expanduser("~/.local/bin/claude")

COMMIT_EVERY   = 10
DELAY_SECS     = 30


def call_claude(prompt: str, retries: int = 3) -> str:
    last_err = ""
    for attempt in range(retries):
        try:
            result = subprocess.run(
                [CLAUDE_BIN, "--print", "-p", prompt],
                capture_output=True, text=True, timeout=120
            )
            if result.returncode == 0 and result.stdout.strip():
                return result.stdout.strip()
            last_err = result.stderr.strip() or result.stdout.strip()
            if "limit" in last_err.lower() or "rate" in last_err.lower():
                print(f"  Rate limit hit — {last_err}")
                raise SystemExit(1)
        except subprocess.TimeoutExpired:
            last_err = "timeout"
        if attempt < retries - 1:
            time.sleep(10)
    raise RuntimeError(f"Claude failed after {retries} retries: {last_err}")


def extract_json(text: str) -> dict:
    """Extract first JSON object from Claude's response."""
    import re
    # Try to find ```json ... ``` block
    m = re.search(r"```(?:json)?\s*(\{[\s\S]*?\})\s*```", text)
    if m:
        return json.loads(m.group(1))
    # Try raw JSON
    m = re.search(r"(\{[\s\S]*\})", text)
    if m:
        return json.loads(m.group(1))
    raise ValueError("No JSON found in response")


PROMPT_TEMPLATE = """You are an ML engineer and educator. Generate code solutions for this ML coding problem.

Problem ID: {id}
Title: {title}
Category: {category}
Difficulty: {difficulty}

Description:
{description}

Starter code (Python):
```python
{starter_code}
```

Generate solutions in:
1. Pure Python (always required)
2. NumPy (if it naturally applies — e.g. matrix ops, numerical computation)
3. TensorFlow (only if relevant — e.g. deep learning, neural networks, gradients)
4. PyTorch (only if relevant — e.g. deep learning, neural networks, autograd)

For each applicable language, provide:
- "code": complete working solution (not just starter code — actually implement it)
- "explanation": 2-4 paragraph explanation of the approach and why it works
- "key_learnings": list of 3-5 bullet points, focused on interview prep insights

Return ONLY a JSON object with this exact structure (use null for non-applicable languages):
{{
  "python": {{"code": "...", "explanation": "...", "key_learnings": ["...", "..."]}},
  "numpy": {{"code": "...", "explanation": "...", "key_learnings": ["...", "..."]}} or null,
  "tensorflow": {{"code": "...", "explanation": "...", "key_learnings": ["...", "..."]}} or null,
  "pytorch": {{"code": "...", "explanation": "...", "key_learnings": ["...", "..."]}} or null
}}"""


def generate_solution(problem: dict) -> dict:
    prompt = PROMPT_TEMPLATE.format(
        id=problem["id"],
        title=problem["title"],
        category=problem["category"],
        difficulty=problem["difficulty"],
        description=problem["description"][:2000],  # truncate very long descriptions
        starter_code=problem.get("starter_code", "# implement here")
    )
    raw = call_claude(prompt)
    sol = extract_json(raw)
    sol["id"] = problem["id"]
    return sol


def git_push(message: str):
    try:
        subprocess.run(["git", "add", "solutions/"], cwd=REPO_ROOT, check=True)
        subprocess.run(["git", "commit", "-m", message], cwd=REPO_ROOT, check=True)
        subprocess.run(["git", "push"], cwd=REPO_ROOT, check=True)
        print(f"  ✓ Pushed: {message}")
    except subprocess.CalledProcessError as e:
        print(f"  Git error: {e}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--start", type=int, default=0, help="Start from this problem index")
    args = parser.parse_args()

    SOLUTIONS_DIR.mkdir(exist_ok=True)

    with open(CHALLENGES_JSON) as f:
        data = json.load(f)
    problems = data["problems"]

    done = 0
    skipped = 0
    errors = []

    for i, problem in enumerate(problems):
        pid = problem["id"]

        # Skip if already generated
        out_file = SOLUTIONS_DIR / f"{pid}.json"
        if out_file.exists():
            skipped += 1
            continue

        # Skip until start index
        if int(pid) < args.start:
            skipped += 1
            continue

        print(f"[{i+1}/{len(problems)}] #{pid} {problem['title'][:50]}", end=" ", flush=True)

        try:
            sol = generate_solution(problem)
            with open(out_file, "w") as f:
                json.dump(sol, f, indent=2, ensure_ascii=False)
            print("✓")
            done += 1
        except SystemExit:
            print(f"\nRate limit — stopping. Re-run after 9am PT to continue.")
            print(f"Done: {done}, Skipped: {skipped}, Errors: {len(errors)}")
            sys.exit(0)
        except Exception as e:
            print(f"✗ {e}")
            errors.append(pid)

        # Commit every N problems
        if done > 0 and done % COMMIT_EVERY == 0:
            git_push(f"feat: solutions batch {done // COMMIT_EVERY} ({done} problems)")

        time.sleep(DELAY_SECS)

    # Final commit
    if done > 0:
        git_push(f"feat: solutions complete — {done} new problems")

    print(f"\nDone: {done} generated, {skipped} skipped, {len(errors)} errors: {errors}")


if __name__ == "__main__":
    main()
