#!/usr/bin/env python3
"""
Enrich papers.json with author affiliations from Semantic Scholar batch API.

Uses the POST /paper/batch endpoint to efficiently fetch author affiliations
for all papers, then extracts company/institution tags from those affiliations.
"""

import json
import re
import time
import urllib.request
import urllib.error

API_BASE = "https://api.semanticscholar.org/graph/v1"
BATCH_SIZE = 400  # API supports up to 500, use 400 for safety

# Map affiliation strings to normalized company names
COMPANY_NORMALIZATION = {
    "google": "Google",
    "deepmind": "Google",
    "google deepmind": "Google",
    "google research": "Google",
    "google brain": "Google",
    "alphabet": "Google",
    "youtube": "Google",
    "meta": "Meta",
    "meta platforms": "Meta",
    "meta ai": "Meta",
    "facebook": "Meta",
    "facebook ai": "Meta",
    "facebook ai research": "Meta",
    "fair": "Meta",
    "instagram": "Meta",
    "pinterest": "Pinterest",
    "pinterest labs": "Pinterest",
    "netflix": "Netflix",
    "snap": "Snap",
    "snap inc": "Snap",
    "snapchat": "Snap",
    "linkedin": "LinkedIn",
    "amazon": "Amazon",
    "amazon science": "Amazon",
    "amazon web services": "Amazon",
    "aws": "Amazon",
    "aws ai": "Amazon",
    "alexa ai": "Amazon",
    "microsoft": "Microsoft",
    "microsoft research": "Microsoft",
    "apple": "Apple",
    "nvidia": "NVIDIA",
    "tiktok": "TikTok",
    "bytedance": "TikTok",
    "kuaishou": "Kuaishou",
    "kuaishou technology": "Kuaishou",
    "alibaba": "Alibaba",
    "alibaba group": "Alibaba",
    "taobao": "Alibaba",
    "ant group": "Alibaba",
    "damo academy": "Alibaba",
    "tencent": "Tencent",
    "tencent ai": "Tencent",
    "wechat": "Tencent",
    "baidu": "Baidu",
    "baidu research": "Baidu",
    "openai": "OpenAI",
    "anthropic": "Anthropic",
    "uber": "Uber",
    "uber technologies": "Uber",
    "airbnb": "Airbnb",
    "spotify": "Spotify",
    "twitter": "Twitter/X",
    "x corp": "Twitter/X",
    "salesforce": "Salesforce",
    "salesforce research": "Salesforce",
    "huawei": "Huawei",
    "huawei technologies": "Huawei",
    "jd.com": "JD.com",
    "jd ai research": "JD.com",
    "jingdong": "JD.com",
    "meituan": "Meituan",
    "xiaohongshu": "Xiaohongshu",
    "samsung": "Samsung",
    "ebay": "eBay",
    "yahoo": "Yahoo",
    "yahoo research": "Yahoo",
    "walmart": "Walmart",
    "walmart labs": "Walmart",
    "instacart": "Instacart",
    "doordash": "DoorDash",
    "booking.com": "Booking.com",
    "adobe": "Adobe",
    "adobe research": "Adobe",
    "ibm": "IBM",
    "ibm research": "IBM",
    "intel": "Intel",
    "intel labs": "Intel",
}


def extract_paper_id(url):
    """Extract Semantic Scholar paper ID or arxiv ID from URL."""
    if "arxiv.org" in url:
        m = re.search(r"abs/(\S+?)(?:\?|$)", url)
        if m:
            return f"ARXIV:{m.group(1)}"
    elif "semanticscholar.org" in url:
        m = re.search(r"/paper/([a-f0-9]+)", url)
        if m:
            return m.group(1)
    return None


def normalize_affiliation(affil_str):
    """Extract company name from an affiliation string."""
    lower = affil_str.lower().strip()
    # Direct match
    for pattern, company in COMPANY_NORMALIZATION.items():
        if pattern in lower:
            return company
    return None


def batch_fetch_affiliations(paper_ids):
    """Fetch author affiliations for a batch of papers using POST /paper/batch."""
    url = f"{API_BASE}/paper/batch?fields=authors.name,authors.affiliations"
    payload = json.dumps({"ids": paper_ids}).encode()

    for attempt in range(5):
        try:
            req = urllib.request.Request(
                url,
                data=payload,
                headers={
                    "User-Agent": "MLPaperExplorer/1.0",
                    "Content-Type": "application/json",
                },
                method="POST",
            )
            with urllib.request.urlopen(req, timeout=60) as resp:
                return json.loads(resp.read().decode())
        except urllib.error.HTTPError as e:
            if e.code == 429 and attempt < 4:
                wait = 10 * (2 ** attempt)
                print(f"  [RATE LIMITED] Waiting {wait}s (attempt {attempt+1}/5)...")
                time.sleep(wait)
            else:
                print(f"  [ERROR] HTTP {e.code}")
                return None
        except Exception as e:
            print(f"  [ERROR] {e}")
            if attempt < 4:
                time.sleep(5)
            else:
                return None
    return None


def main():
    print("Loading papers.json...")
    with open("papers.json") as f:
        papers = json.load(f)

    print(f"Total papers: {len(papers)}")

    # Build paper_id -> index mapping
    id_to_indices = {}
    paper_ids = []
    for i, p in enumerate(papers):
        pid = extract_paper_id(p.get("url", ""))
        if pid:
            if pid not in id_to_indices:
                id_to_indices[pid] = []
                paper_ids.append(pid)
            id_to_indices[pid].append(i)

    print(f"Papers with extractable IDs: {len(paper_ids)}")

    # Batch fetch affiliations
    all_results = {}
    total_batches = (len(paper_ids) + BATCH_SIZE - 1) // BATCH_SIZE

    for batch_num in range(total_batches):
        start = batch_num * BATCH_SIZE
        end = min(start + BATCH_SIZE, len(paper_ids))
        batch_ids = paper_ids[start:end]

        print(f"  Batch {batch_num+1}/{total_batches}: fetching {len(batch_ids)} papers...")
        results = batch_fetch_affiliations(batch_ids)

        if results is None:
            print(f"  Batch {batch_num+1} failed, skipping")
            continue

        for pid, result in zip(batch_ids, results):
            if result is not None:
                all_results[pid] = result

        # Rate limit: wait between batches
        if batch_num < total_batches - 1:
            time.sleep(3)

    print(f"\nFetched affiliations for {len(all_results)} papers")

    # Extract companies from affiliations
    updated = 0
    for pid, result in all_results.items():
        companies_from_affil = set()

        for author in (result.get("authors") or []):
            for affil in (author.get("affiliations") or []):
                company = normalize_affiliation(affil)
                if company:
                    companies_from_affil.add(company)

        if companies_from_affil:
            for idx in id_to_indices.get(pid, []):
                existing = set(papers[idx].get("companies", []))
                merged = sorted(existing | companies_from_affil)
                if merged != papers[idx].get("companies", []):
                    papers[idx]["companies"] = merged
                    updated += 1

    print(f"Updated companies on {updated} papers")

    # Show new company counts
    from collections import Counter
    company_counts = Counter()
    papers_with_company = 0
    for p in papers:
        if p.get("companies"):
            papers_with_company += 1
            for c in p["companies"]:
                company_counts[c] += 1

    print(f"\nPapers with companies: {papers_with_company}/{len(papers)}")
    print("Company counts:")
    for c, n in company_counts.most_common():
        print(f"  {c:20s} {n:4d}")

    # Save
    with open("papers.json", "w") as f:
        json.dump(papers, f)
    print(f"\nSaved to papers.json")


if __name__ == "__main__":
    main()
