#!/usr/bin/env python3
"""Merge AI-generated summaries from batch files into papers.json."""

import json
import glob
import sys

def main():
    with open("papers.json") as f:
        papers = json.load(f)

    url_to_idx = {}
    for i, p in enumerate(papers):
        url_to_idx[p["url"]] = i

    total_merged = 0
    batch_files = sorted(glob.glob("ai_summaries_batch*.json"))
    print(f"Found {len(batch_files)} batch files")

    for batch_file in batch_files:
        try:
            with open(batch_file) as f:
                summaries = json.load(f)
            count = 0
            for entry in summaries:
                url = entry.get("url", "")
                bullets = entry.get("ai_summary_bullets", [])
                if url in url_to_idx and bullets and len(bullets) >= 2:
                    papers[url_to_idx[url]]["ai_summary_bullets"] = bullets
                    count += 1
            print(f"  {batch_file}: merged {count}/{len(summaries)} summaries")
            total_merged += count
        except Exception as e:
            print(f"  {batch_file}: ERROR - {e}")

    with open("papers.json", "w") as f:
        json.dump(papers, f)

    has_ai = sum(1 for p in papers if p.get("ai_summary_bullets"))
    print(f"\nTotal merged: {total_merged}")
    print(f"Papers with AI summaries: {has_ai}/{len(papers)}")
    print("Saved to papers.json")

if __name__ == "__main__":
    main()
