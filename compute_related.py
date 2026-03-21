#!/usr/bin/env python3
"""
Compute related papers using TF-IDF cosine similarity.
Adds a 'related_papers' field (list of URLs) to each paper in papers.json.

Usage:
    python compute_related.py                  # Default: top 5 related
    python compute_related.py --top-k 8        # Top 8 related
    python compute_related.py --recompute      # Force recompute even if field exists
"""

import argparse
import json
import re
import sys
from collections import Counter
import math


def tokenize(text):
    """Simple tokenizer: lowercase, split on non-alpha, remove stopwords."""
    stopwords = {
        "a", "an", "the", "and", "or", "but", "in", "on", "at", "to", "for",
        "of", "with", "by", "from", "is", "are", "was", "were", "be", "been",
        "being", "have", "has", "had", "do", "does", "did", "will", "would",
        "could", "should", "may", "might", "can", "shall", "it", "its",
        "this", "that", "these", "those", "we", "our", "us", "they", "their",
        "them", "he", "she", "his", "her", "i", "me", "my", "you", "your",
        "not", "no", "nor", "as", "if", "then", "than", "so", "such",
        "also", "more", "most", "very", "just", "about", "which", "who",
        "whom", "what", "when", "where", "how", "all", "each", "every",
        "both", "few", "many", "some", "any", "other", "into", "over",
        "after", "before", "between", "through", "during", "above", "below",
        "up", "down", "out", "off", "only", "own", "same", "while",
        "because", "until", "again", "further", "here", "there", "once",
        "paper", "propose", "proposed", "method", "approach", "results",
        "show", "based", "using", "used", "use", "new", "however",
    }
    words = re.findall(r'[a-z][a-z0-9]+', text.lower())
    return [w for w in words if w not in stopwords and len(w) > 2]


def build_bigrams(tokens):
    """Generate bigrams from token list."""
    return [f"{tokens[i]}_{tokens[i+1]}" for i in range(len(tokens) - 1)]


def compute_tfidf(papers):
    """Compute TF-IDF vectors for all papers."""
    print("Tokenizing papers...")
    docs = []
    for p in papers:
        text = f"{p['title']} {p['title']} {p.get('abstract', '')} {p.get('topic', '')}"
        tokens = tokenize(text)
        bigrams = build_bigrams(tokens)
        docs.append(tokens + bigrams)

    # Document frequency
    print("Computing document frequencies...")
    n = len(docs)
    df = Counter()
    for doc in docs:
        for term in set(doc):
            df[term] += 1

    # Filter: keep terms appearing in at least 2 docs and at most 80% of docs
    max_df = int(n * 0.8)
    vocab = {term for term, count in df.items() if 2 <= count <= max_df}
    vocab_list = sorted(vocab)
    term_to_idx = {t: i for i, t in enumerate(vocab_list)}
    print(f"Vocabulary size: {len(vocab_list)}")

    # IDF
    idf = {}
    for term in vocab_list:
        idf[term] = math.log(n / (1 + df[term]))

    # Build sparse TF-IDF vectors
    print("Building TF-IDF vectors...")
    vectors = []
    for doc in docs:
        tf = Counter(t for t in doc if t in vocab)
        total = len(doc) or 1
        vec = {}
        for term, count in tf.items():
            vec[term_to_idx[term]] = (count / total) * idf[term]
        # Normalize
        norm = math.sqrt(sum(v * v for v in vec.values())) or 1
        vec = {k: v / norm for k, v in vec.items()}
        vectors.append(vec)

    return vectors


def cosine_sim(v1, v2):
    """Cosine similarity between two sparse vectors (dicts)."""
    if not v1 or not v2:
        return 0.0
    common = set(v1.keys()) & set(v2.keys())
    if not common:
        return 0.0
    return sum(v1[k] * v2[k] for k in common)


def compute_related(papers, vectors, top_k=5):
    """For each paper, find top-k most similar papers."""
    n = len(papers)
    url_to_idx = {p['url']: i for i, p in enumerate(papers)}

    print(f"Computing similarities for {n} papers...")
    batch_size = 100
    for start in range(0, n, batch_size):
        end = min(start + batch_size, n)
        if start % 500 == 0:
            print(f"  Processing {start}/{n}...")
        for i in range(start, end):
            scores = []
            for j in range(n):
                if i == j:
                    continue
                sim = cosine_sim(vectors[i], vectors[j])
                if sim > 0.05:
                    scores.append((sim, j))
            scores.sort(key=lambda x: -x[0])
            papers[i]['related_papers'] = [papers[j]['url'] for _, j in scores[:top_k]]

    return papers


def main():
    parser = argparse.ArgumentParser(description="Compute related papers via TF-IDF similarity")
    parser.add_argument("--input", default="papers.json", help="Input JSON file")
    parser.add_argument("--top-k", type=int, default=5, help="Number of related papers per paper")
    parser.add_argument("--recompute", action="store_true", help="Force recompute")
    args = parser.parse_args()

    with open(args.input) as f:
        papers = json.load(f)
    print(f"Loaded {len(papers)} papers")

    if not args.recompute and papers and papers[0].get('related_papers'):
        print("Related papers already computed. Use --recompute to force.")
        return

    vectors = compute_tfidf(papers)
    papers = compute_related(papers, vectors, args.top_k)

    with open(args.input, 'w') as f:
        json.dump(papers, f)
    print(f"Saved {len(papers)} papers with related_papers field")


if __name__ == "__main__":
    main()
