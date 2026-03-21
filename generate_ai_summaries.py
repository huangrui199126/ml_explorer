#!/usr/bin/env python3
"""
Generate high-quality AI summaries for ML papers using Claude API.
Summaries are designed for ML interview prep — focusing on key technical
contributions, architecture decisions, and practical insights.

Usage:
    python generate_ai_summaries.py                    # Process all papers without AI summaries
    python generate_ai_summaries.py --limit 100        # Process first 100 papers
    python generate_ai_summaries.py --recompute        # Recompute all summaries
    python generate_ai_summaries.py --batch-size 20    # Process 20 at a time
"""

import argparse
import json
import os
import time
import sys

USE_BEDROCK = os.environ.get("CLAUDE_CODE_USE_BEDROCK") == "1" or not os.environ.get("ANTHROPIC_API_KEY")

if USE_BEDROCK:
    import anthropic
    # Use AWS Bedrock
    client_cls = anthropic.AnthropicBedrock
    DEFAULT_MODEL = "us.anthropic.claude-haiku-4-5-20251001-v1:0"
else:
    import anthropic
    client_cls = anthropic.Anthropic
    DEFAULT_MODEL = "claude-haiku-4-5-20251001"

PROMPT_TEMPLATE = """You are a senior ML engineer at a top tech company. Analyze this research paper and provide exactly 3 bullet points for ML interview preparation.

USE YOUR FULL WORLD KNOWLEDGE about this paper, its authors, the related work, and the broader field — not just the abstract. If you recognize this paper, include details about its real-world deployment, follow-up work, or industry adoption that go beyond the abstract.

For each bullet point:

1. **Problem & Motivation**: What specific technical challenge does this address? Why do prior approaches (name them if you know) fall short? Be concrete about the gap — e.g., "DHEN addresses the challenge of applying deep hierarchical ensemble networks to CVR prediction in ads, where key design decisions like which feature-crossing modules to include and network depth significantly impact performance at web scale."

2. **Key Technical Contribution**: What is the novel architecture, loss function, training strategy, or system design? Describe specific design decisions and trade-offs. Name the model backbone, key components, and what makes them different — e.g., "combines a multitask learning framework with DHEN as the backbone, integrates both on-site user behavior sequences and off-site conversion event sequences, and introduces a self-supervised auxiliary loss that predicts future actions to mitigate label sparseness in CVR prediction."

3. **Results & Practical Impact**: Quantitative results, production deployment details, and practical takeaways. Which company deployed it? What metrics improved? What's the key lesson for building real systems? — e.g., "achieves state-of-the-art over single feature-crossing baselines and has been successfully deployed in Pinterest's conversion ad recommendation system, demonstrating significant improvements in both user and advertiser value."

Keep each bullet to 1-3 sentences. Be SPECIFIC and TECHNICAL. Never be generic. Reference actual model names, techniques, metrics, companies, and numbers.

Title: {title}
Authors: {authors}
Venue: {venue} {year}
Abstract: {abstract}"""


def generate_summaries_batch(client, papers, model, start_idx=0):
    """Generate AI summaries for a batch of papers."""
    results = []
    for i, paper in enumerate(papers):
        idx = start_idx + i
        title = paper.get("title", "")
        abstract = paper.get("abstract", "")
        if not abstract:
            results.append(None)
            continue

        authors_list = ", ".join(paper.get("authors", [])[:8])
        prompt = PROMPT_TEMPLATE.format(
            title=title,
            authors=authors_list or "N/A",
            venue=paper.get("venue", "N/A"),
            year=paper.get("year", "N/A"),
            abstract=abstract[:2000],
        )

        for attempt in range(3):
            try:
                response = client.messages.create(
                    model=model,
                    max_tokens=400,
                    messages=[{"role": "user", "content": prompt}],
                )
                text = response.content[0].text.strip()
                bullets = parse_bullets(text)
                results.append(bullets)

                if (idx + 1) % 10 == 0:
                    print(f"  [{idx + 1}] {title[:60]}...")

                # Rate limit: ~50 requests/min for Haiku
                time.sleep(0.3)
                break
            except anthropic.RateLimitError:
                wait = 10 * (attempt + 1)
                print(f"  [RATE LIMITED] Waiting {wait}s...")
                time.sleep(wait)
            except Exception as e:
                print(f"  [ERROR] Paper {idx}: {e}")
                results.append(None)
                break
        else:
            results.append(None)

    return results


def parse_bullets(text):
    """Parse Claude's response into structured bullets."""
    bullets = []
    lines = text.strip().split("\n")

    current_type = None
    current_text = ""
    type_map = {
        "1": "problem",
        "2": "method",
        "3": "result",
    }

    for line in lines:
        line = line.strip()
        if not line:
            continue

        # Detect numbered bullet
        matched = False
        for num, btype in type_map.items():
            if line.startswith(f"{num}.") or line.startswith(f"{num})"):
                if current_type and current_text:
                    bullets.append({"type": current_type, "text": clean_bullet(current_text)})
                current_type = btype
                # Remove the number prefix and any bold markers
                current_text = line.split(".", 1)[-1].strip() if "." in line[:3] else line[2:].strip()
                matched = True
                break

        if not matched and current_type:
            current_text += " " + line

    if current_type and current_text:
        bullets.append({"type": current_type, "text": clean_bullet(current_text)})

    return bullets if len(bullets) >= 2 else None


def clean_bullet(text):
    """Clean up bullet text — remove markdown bold markers, extra whitespace."""
    text = text.strip()
    # Remove leading bold label like "**Problem & Motivation:**" or "**Key Technical Contribution:**"
    import re
    text = re.sub(r'^\*\*[^*]+\*\*:?\s*', '', text)
    text = re.sub(r'\*\*', '', text)
    text = re.sub(r'\s+', ' ', text)
    return text.strip()


def main():
    parser = argparse.ArgumentParser(description="Generate AI summaries using Claude")
    parser.add_argument("--input", default="papers.json", help="Input JSON file")
    parser.add_argument("--limit", type=int, default=0, help="Max papers to process (0=all)")
    parser.add_argument("--batch-size", type=int, default=50, help="Save checkpoint every N papers")
    parser.add_argument("--recompute", action="store_true", help="Recompute all summaries")
    parser.add_argument("--min-score", type=int, default=0, help="Only process papers with score >= N")
    args = parser.parse_args()

    with open(args.input) as f:
        papers = json.load(f)
    print(f"Loaded {len(papers)} papers")

    client = client_cls()
    model = DEFAULT_MODEL
    print(f"Using {'Bedrock' if USE_BEDROCK else 'Anthropic API'} with model: {model}")

    # Filter papers that need summaries
    to_process = []
    for i, p in enumerate(papers):
        if args.min_score and (p.get("score", 0) < args.min_score):
            continue
        if not args.recompute and p.get("ai_summary_bullets"):
            continue
        to_process.append((i, p))

    if args.limit:
        to_process = to_process[:args.limit]

    print(f"Papers to process: {len(to_process)}")
    if not to_process:
        print("Nothing to do.")
        return

    # Estimate cost
    avg_input_tokens = 500  # ~500 tokens per abstract
    avg_output_tokens = 250
    total_input = len(to_process) * avg_input_tokens
    total_output = len(to_process) * avg_output_tokens
    # Haiku pricing: $1/M input, $5/M output
    est_cost = (total_input / 1_000_000) * 1.0 + (total_output / 1_000_000) * 5.0
    print(f"Estimated cost: ~${est_cost:.2f} (Haiku)")
    print(f"Estimated time: ~{len(to_process) * 0.4 / 60:.1f} min")
    print()

    processed = 0
    failed = 0

    for batch_start in range(0, len(to_process), args.batch_size):
        batch = to_process[batch_start:batch_start + args.batch_size]
        batch_papers = [p for _, p in batch]
        batch_indices = [i for i, _ in batch]

        print(f"Batch {batch_start // args.batch_size + 1}: papers {batch_start + 1}-{batch_start + len(batch)}")

        results = generate_summaries_batch(client, batch_papers, model, start_idx=batch_start)

        for (paper_idx, _), bullets in zip(batch, results):
            if bullets:
                papers[paper_idx]["ai_summary_bullets"] = bullets
                processed += 1
            else:
                failed += 1

        # Save checkpoint
        with open(args.input, "w") as f:
            json.dump(papers, f)
        print(f"  Checkpoint saved. Processed: {processed}, Failed: {failed}")

    print(f"\nDone! Processed: {processed}, Failed: {failed}")
    print(f"Saved to {args.input}")


if __name__ == "__main__":
    main()
