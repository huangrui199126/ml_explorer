#!/usr/bin/env python3
"""
Fetch ML papers focused on Search, Recommendation, LLM, and Generative Retrieval
from Semantic Scholar API. Papers from top industry labs and conferences.

Usage:
    python fetch_papers.py                          # Fetch all topics
    python fetch_papers.py --topics "LLM ranking"   # Specific topics
    python fetch_papers.py --max-per-topic 200      # More papers per topic
    python fetch_papers.py --append                  # Add to existing papers.json
    python fetch_papers.py --enrich                  # Re-compute scores/summaries
"""

import argparse
import json
import math
import re
import time
import urllib.request
import urllib.parse
import urllib.error
from datetime import datetime

API_BASE = "https://api.semanticscholar.org/graph/v1"
FIELDS = "title,abstract,authors.name,authors.affiliations,year,venue,url,citationCount,publicationDate,externalIds,fieldsOfStudy,publicationTypes,influentialCitationCount"

# Search & Recommendation focused topics
DEFAULT_TOPICS = {
    # === Ranking & Search ===
    "Learning to Rank": [
        "learning to rank neural",
        "search ranking relevance model",
        "query document matching deep learning",
        "semantic search neural retrieval",
        "search relevance optimization",
    ],
    "Dense Retrieval & Embedding": [
        "dense retrieval passage embedding",
        "bi-encoder dense retrieval",
        "approximate nearest neighbor search",
        "embedding based retrieval",
        "representation learning retrieval",
    ],
    "Search & Relevance": [
        "web search ranking neural",
        "query understanding intent classification",
        "query rewriting reformulation",
        "search result diversification",
        "conversational search dialogue",
    ],
    # === Recommendation Systems ===
    "CTR/CVR Prediction": [
        "click through rate prediction deep learning",
        "conversion rate prediction",
        "CTR prediction feature interaction",
        "deep interest network recommendation",
        "user response prediction advertising",
    ],
    "Collaborative Filtering": [
        "collaborative filtering neural",
        "matrix factorization recommendation",
        "implicit feedback recommendation",
        "user item interaction modeling",
        "autoencoder collaborative filtering",
    ],
    "Sequential Recommendation": [
        "sequential recommendation transformer",
        "session based recommendation",
        "next item prediction",
        "user behavior sequence modeling",
        "temporal recommendation model",
    ],
    "Multi-task Learning": [
        "multi-task learning recommendation",
        "multi-objective optimization recommendation",
        "auxiliary task recommendation",
        "shared bottom multi-task",
        "multi-task ranking model",
    ],
    "Feature Interaction": [
        "feature interaction deep recommendation",
        "factorization machine deep learning",
        "cross network feature interaction",
        "feature embedding recommendation",
        "automatic feature interaction",
    ],
    "User Behavior Modeling": [
        "user behavior modeling recommendation",
        "user interest modeling deep learning",
        "attention mechanism user behavior",
        "user engagement prediction",
        "user representation learning",
    ],
    "Ranking": [
        "listwise ranking optimization",
        "re-ranking recommendation",
        "cascade ranking model",
        "ranking optimization deep learning",
        "slate recommendation ranking",
    ],
    "Graph & Knowledge": [
        "graph neural network recommendation",
        "knowledge graph recommendation",
        "social network recommendation",
        "heterogeneous graph recommendation",
        "graph collaborative filtering",
    ],
    # === Generative & LLM ===
    "Generative & LLM": [
        "large language model recommendation",
        "LLM recommendation system",
        "generative recommendation model",
        "foundation model recommendation",
        "prompt tuning recommendation",
    ],
    "Generative Retrieval": [
        "generative retrieval document identifier",
        "generative search model",
        "autoregressive retrieval",
        "differentiable search index",
        "generative recommendation retrieval",
    ],
    "LLM for Search": [
        "large language model search ranking",
        "LLM query understanding",
        "LLM relevance judgment",
        "retrieval augmented generation search",
        "LLM information retrieval",
    ],
    "Content Understanding": [
        "content understanding embedding",
        "multimodal content recommendation",
        "text understanding classification",
        "video understanding recommendation",
        "content-based filtering deep learning",
    ],
    # === Industrial Systems ===
    "Scaling & Industrial Systems": [
        "industrial recommendation system",
        "recommendation system production",
        "real-time recommendation serving",
        "large scale recommendation",
        "recommendation system infrastructure",
    ],
    "Retrieval & Embedding": [
        "two tower model recommendation",
        "candidate retrieval recommendation",
        "embedding retrieval production",
        "vector search recommendation",
        "negative sampling recommendation",
    ],
    "Ads & Monetization": [
        "computational advertising deep learning",
        "ad click prediction model",
        "bid optimization advertising",
        "auction mechanism advertising",
        "advertising recommendation system",
    ],
    # === Frontier Topics ===
    "Reinforcement Learning for Rec": [
        "reinforcement learning recommendation",
        "bandit algorithm recommendation",
        "exploration exploitation recommendation",
        "reward modeling recommendation",
        "online learning recommendation",
    ],
    "Fairness & Bias": [
        "fairness recommendation system",
        "bias mitigation recommendation",
        "calibration recommendation",
        "debiasing recommendation",
        "popularity bias recommendation",
    ],
    "Cold Start & Few-shot": [
        "cold start recommendation",
        "few-shot recommendation",
        "zero-shot recommendation",
        "meta-learning recommendation",
        "cross-domain recommendation",
    ],
    "Evaluation & Metrics": [
        "offline evaluation recommendation",
        "A/B testing recommendation",
        "counterfactual evaluation",
        "recommendation evaluation metric",
        "online experiment recommendation",
    ],
    "LLM Alignment & Safety": [
        "reinforcement learning human feedback",
        "LLM alignment safety",
        "instruction tuning large language model",
        "constitutional AI alignment",
        "red teaming language model",
    ],
    "LLM Efficiency": [
        "efficient inference large language model",
        "model compression LLM",
        "parameter efficient fine-tuning",
        "LoRA adapter language model",
        "quantization large language model",
    ],
    "RAG & Agents": [
        "retrieval augmented generation",
        "tool use language model agent",
        "LLM agent planning reasoning",
        "agentic AI system",
        "chain of thought reasoning",
    ],
}

# Top venues for search/rec/LLM
TOP_VENUES = {
    "KDD", "RecSys", "SIGIR", "WSDM", "WWW", "CIKM",
    "NeurIPS", "ICML", "ICLR", "AAAI",
    "ACL", "EMNLP", "NAACL",
    "ICDE", "VLDB",
    "Nature", "Science", "JMLR", "TPAMI",
}

# Top companies for industry papers
TOP_COMPANIES = {
    "google", "meta", "facebook", "netflix", "pinterest", "tiktok", "bytedance",
    "kuaishou", "alibaba", "amazon", "microsoft", "apple", "nvidia",
    "openai", "anthropic", "deepmind", "baidu", "tencent", "linkedin",
    "uber", "airbnb", "spotify", "twitter", "snap", "salesforce",
    "huawei", "samsung", "jd.com", "meituan", "xiaohongshu",
}


def compute_score(paper):
    """
    Compute an interview-usefulness score (0-100) optimized for ML engineer
    interviews at top-tier companies (Google, Meta, Pinterest, Netflix, Snap).

    Scoring priorities:
    1. Recency (up to 25) — latest papers are most interview-relevant
    2. Topic relevance (up to 20) — core search/rec/ranking > frontier LLM
    3. Industry origin (up to 18) — tier-1 interview companies get premium
    4. Practical/backbone keywords (up to 12) — systems & architectures
    5. Venue prestige (up to 12) — top rec/search venues weighted higher
    6. Citations (up to 13) — still matters but de-weighted
    """
    citations = paper.get("citations", 0)
    influential = paper.get("influential_citations", 0)
    venue = paper.get("venue", "")
    year = paper.get("year", 2020)
    authors = " ".join(paper.get("authors", [])).lower()
    title = paper.get("title", "").lower()
    abstract = paper.get("abstract", "").lower()
    topic = paper.get("topic", "")
    text = title + " " + abstract

    # --- 1. Recency (up to 25) — strong preference for latest papers ---
    current_year = datetime.now().year
    years_old = max(0, current_year - year)
    if years_old == 0:
        recency_score = 25
    elif years_old == 1:
        recency_score = 22
    elif years_old == 2:
        recency_score = 17
    elif years_old == 3:
        recency_score = 12
    elif years_old == 4:
        recency_score = 7
    elif years_old == 5:
        recency_score = 3
    else:
        recency_score = 1

    # --- 2. Topic relevance tiers (up to 20) ---
    # Tier 1: Core rec/search/ranking — most asked in interviews
    tier1_topics = {
        "CTR/CVR Prediction", "Learning to Rank", "Ranking",
        "Retrieval & Embedding", "Feature Interaction",
        "Multi-task Learning", "Sequential Recommendation",
        "User Behavior Modeling", "Dense Retrieval & Embedding",
    }
    # Tier 2: Important for system design interviews
    tier2_topics = {
        "Scaling & Industrial Systems", "Search & Relevance",
        "Collaborative Filtering", "Ads & Monetization",
        "Generative Retrieval", "LLM for Search",
        "Generative & LLM", "Graph & Knowledge",
    }
    # Tier 3: Good to know, less directly asked
    tier3_topics = {
        "Content Understanding", "Cold Start & Few-shot",
        "Evaluation & Metrics", "Reinforcement Learning for Rec",
        "RAG & Agents",
    }
    if topic in tier1_topics:
        topic_score = 20
    elif topic in tier2_topics:
        topic_score = 14
    elif topic in tier3_topics:
        topic_score = 8
    else:
        topic_score = 3

    # --- 3. Industry origin (up to 18) — tiered by interview relevance ---
    # Tier 1: Companies where you'd interview — their papers are gold
    tier1_companies = {
        "google", "deepmind", "meta", "facebook", "pinterest",
        "netflix", "snap", "linkedin", "amazon",
    }
    # Tier 2: Major ML companies with strong rec/search systems
    tier2_companies = {
        "microsoft", "apple", "nvidia", "tiktok", "bytedance",
        "kuaishou", "alibaba", "uber", "airbnb", "spotify",
    }
    # Tier 3: Other notable companies
    tier3_companies = {
        "openai", "anthropic", "baidu", "tencent", "twitter",
        "salesforce", "huawei", "samsung", "jd.com", "meituan",
        "xiaohongshu",
    }
    industry_score = 0
    for company in tier1_companies:
        if company in authors:
            industry_score = 18
            break
    if industry_score == 0:
        for company in tier2_companies:
            if company in authors:
                industry_score = 12
                break
    if industry_score == 0:
        for company in tier3_companies:
            if company in authors:
                industry_score = 6
                break

    # --- 4. Practical/backbone keyword boost (up to 12) ---
    # Papers about concrete model architectures & production systems
    backbone_keywords = [
        "transformer", "attention mechanism", "bert", "two-tower",
        "dual encoder", "cross-encoder", "deep interest",
        "feature interaction", "wide and deep", "deepfm", "dcn",
        "din", "dien", "mmoe", "ple", "esmm",
    ]
    system_keywords = [
        "production", "industrial", "large-scale", "real-time",
        "serving", "infrastructure", "a/b test", "online experiment",
        "system design", "end-to-end", "deployment",
    ]
    interview_keywords = [
        "embedding", "negative sampling", "contrastive learning",
        "knowledge distillation", "multi-task", "cold start",
        "exploration", "calibration", "position bias",
    ]
    keyword_hits = 0
    for kw in backbone_keywords:
        if kw in text:
            keyword_hits += 2
    for kw in system_keywords:
        if kw in text:
            keyword_hits += 2
    for kw in interview_keywords:
        if kw in text:
            keyword_hits += 1
    keyword_score = min(12, keyword_hits)

    # --- 5. Venue prestige (up to 12) — search/rec venues weighted higher ---
    venue_upper = venue.upper()
    top_rec_search_venues = {"KDD", "RECSYS", "SIGIR", "WSDM", "WWW", "CIKM"}
    top_ml_venues = {"NEURIPS", "ICML", "ICLR", "AAAI"}
    top_nlp_venues = {"ACL", "EMNLP", "NAACL"}
    venue_score = 0
    for v in top_rec_search_venues:
        if v in venue_upper:
            venue_score = 12
            break
    if venue_score == 0:
        for v in top_ml_venues:
            if v in venue_upper:
                venue_score = 8
                break
    if venue_score == 0:
        for v in top_nlp_venues:
            if v in venue_upper:
                venue_score = 6
                break

    # --- 6. Citations (up to 13) — still counts but less dominant ---
    cite_score = min(10, math.log1p(citations) * 1.5)
    inf_score = min(3, math.log1p(influential) * 1.5)

    total = recency_score + topic_score + industry_score + keyword_score + venue_score + cite_score + inf_score
    return min(99, max(1, round(total)))


def detect_companies(paper):
    """Detect which companies are associated with a paper based on author affiliations and title/abstract."""
    authors = " ".join(paper.get("authors", [])).lower()
    title = paper.get("title", "").lower()
    abstract = paper.get("abstract", "").lower()
    text = authors + " " + title + " " + abstract

    # Patterns matched against author names and title only (high confidence)
    company_map = {
        "Google": ["google", "deepmind", "alphabet"],
        "Meta": ["meta", "facebook"],
        "Pinterest": ["pinterest"],
        "Netflix": ["netflix"],
        "Snap": ["snap inc", "snapchat"],
        "LinkedIn": ["linkedin"],
        "Amazon": ["amazon"],
        "Microsoft": ["microsoft"],
        "Apple": ["apple inc"],
        "NVIDIA": ["nvidia"],
        "TikTok": ["tiktok", "bytedance"],
        "Kuaishou": ["kuaishou"],
        "Alibaba": ["alibaba", "taobao", "alipay", "ant group"],
        "Tencent": ["tencent", "wechat"],
        "Baidu": ["baidu"],
        "OpenAI": ["openai"],
        "Anthropic": ["anthropic"],
        "Uber": ["uber"],
        "Airbnb": ["airbnb"],
        "Spotify": ["spotify"],
        "Twitter/X": ["twitter"],
        "Salesforce": ["salesforce"],
        "Huawei": ["huawei"],
        "JD.com": ["jd.com", "jingdong"],
        "Meituan": ["meituan"],
        "Xiaohongshu": ["xiaohongshu"],
        "Samsung": ["samsung"],
        "eBay": ["ebay"],
        "Yahoo": ["yahoo"],
        "Walmart": ["walmart"],
        "Instacart": ["instacart"],
        "DoorDash": ["doordash"],
        "Booking.com": ["booking.com"],
    }

    # More specific patterns matched against title only (company product/system mentions)
    title_system_map = {
        "Google": ["google search", "google play", "google ads", "google recommend", "google news", "youtube recommend", "gmail"],
        "Meta": ["instagram recommend", "facebook marketplace", "meta recommend"],
        "Pinterest": ["pinterest"],
        "Netflix": ["netflix"],
        "TikTok": ["tiktok", "douyin"],
        "Alibaba": ["taobao", "tmall"],
        "Kuaishou": ["kuaishou"],
    }

    # High-confidence abstract affiliation patterns (e.g., "deployed at Google", "at Netflix")
    abstract_affiliation_map = {
        "Google": ["google research", "google deepmind", "google brain", "deployed at google", "at google", "google's recommend", "google's search"],
        "Meta": ["meta platforms", "meta ai", "facebook ai", "deployed at meta", "at meta", "at facebook"],
        "Pinterest": ["deployed at pinterest", "at pinterest", "pinterest's"],
        "Netflix": ["deployed at netflix", "at netflix", "netflix's recommend", "netflix prize"],
        "Snap": ["deployed at snap", "at snap inc"],
        "LinkedIn": ["deployed at linkedin", "at linkedin", "linkedin's"],
        "Amazon": ["amazon science", "amazon's recommend", "deployed at amazon", "alexa ai", "amazon search"],
        "Microsoft": ["microsoft research", "deployed at microsoft", "at microsoft", "bing search"],
        "TikTok": ["deployed at tiktok", "at tiktok", "deployed at bytedance", "at bytedance"],
        "Kuaishou": ["deployed at kuaishou", "at kuaishou", "kuaishou's"],
        "Alibaba": ["deployed at alibaba", "at alibaba", "alibaba's", "deployed at taobao", "at taobao"],
        "Tencent": ["deployed at tencent", "at tencent", "tencent's"],
        "Baidu": ["deployed at baidu", "at baidu", "baidu's search"],
        "Uber": ["deployed at uber", "at uber", "uber eats"],
        "Airbnb": ["deployed at airbnb", "at airbnb", "airbnb's"],
        "Spotify": ["deployed at spotify", "at spotify", "spotify's"],
        "eBay": ["deployed at ebay", "at ebay", "ebay's"],
        "Walmart": ["deployed at walmart", "at walmart"],
        "Instacart": ["deployed at instacart", "at instacart"],
        "DoorDash": ["deployed at doordash", "at doordash"],
    }

    found = []
    for display_name, patterns in company_map.items():
        for pattern in patterns:
            if pattern in authors or pattern in title:
                found.append(display_name)
                break

    # Check title for company-specific system/product mentions
    for display_name, patterns in title_system_map.items():
        if display_name not in found:
            for pattern in patterns:
                if pattern in title:
                    found.append(display_name)
                    break

    # Check abstract for explicit affiliation phrases
    for display_name, patterns in abstract_affiliation_map.items():
        if display_name not in found:
            for pattern in patterns:
                if pattern in abstract:
                    found.append(display_name)
                    break

    return sorted(set(found))


# Knowledge tags: ML concepts/techniques relevant to interview prep
KNOWLEDGE_TAG_PATTERNS = {
    "CTR/CVR Prediction": ["click.through rate", "ctr prediction", "conversion rate", "cvr prediction", "click prediction"],
    "Feature Interaction": ["feature interaction", "feature crossing", "cross network", "factorization machine", "deepfm", "dcn", "wide and deep", "autoint"],
    "Ranking": ["learning to rank", "listwise", "pairwise", "pointwise", "re.ranking", "reranking", "ranking model", "ranking optimization"],
    "Sequential Recommendation": ["sequential recommend", "session.based recommend", "next item", "user behavior sequence", "sasrec", "bert4rec", "gru4rec"],
    "Multi-task Learning": ["multi.task.*model", "multi.task.*framework", "multi.task.*train", "multi.objective optim", "mmoe", "ple ", "shared.bottom", "expert.*network.*task", "pareto.*optim"],
    "Retrieval & Embedding": ["two.tower", "dual encoder", "candidate retrieval", "embedding.based retrieval", "vector search", "approximate nearest neighbor", "ann search", "faiss", "hnsw"],
    "Dense Retrieval": ["dense retrieval", "dense passage", "bi.encoder", "representation learning retrieval", "contrastive.*retrieval"],
    "User Behavior Modeling": ["user behavior model", "user interest model", "din ", "dien", "deep interest", "attention.*user", "user engagement", "user representation"],
    "Collaborative Filtering": ["collaborative filter", "matrix factorization", "implicit feedback", "user.item interaction"],
    "Graph Neural Network": ["graph neural", "graph convolution", "gnn", "knowledge graph", "heterogeneous graph", "lightgcn", "graph attention"],
    "Generative Retrieval": ["generative retrieval", "generative search", "differentiable search index", "autoregressive retrieval", "document identifier"],
    "LLM for Rec/Search": ["large language model.*recommend", "llm.*recommend", "llm.*search", "llm.*ranking", "foundation model.*recommend", "prompt.*recommend"],
    "Transformer": ["transformer", "self.attention", "multi.head attention"],
    "Contrastive Learning": ["contrastive learn", "contrastive loss", "simclr", "moco", "infonce", "negative sampling"],
    "Knowledge Distillation": ["knowledge distill", "teacher.student", "model compress", "model distill"],
    "Cold Start": ["cold start", "cold.start", "few.shot recommend", "zero.shot recommend", "meta.learn.*recommend"],
    "Calibration & Bias": ["calibration", "position bias", "selection bias", "debiasing", "popularity bias", "exposure bias"],
    "Ads & Monetization": ["computational advertis", "ad click", "bid optimiz", "auction", "advertis.*recommend", "sponsored"],
    "Scaling & Industrial Systems": ["industrial.*system", "production.*recommend", "real.time.*recommend", "large.scale.*recommend", "serving.*recommend", "infrastructure"],
    "A/B Testing & Evaluation": ["a/b test", "online experiment", "offline evaluation", "counterfactual", "interleaving"],
    "RAG": ["retrieval.augmented generation", "retrieval augmented", "rag "],
    "Reinforcement Learning": ["reinforcement learn.*recommend", "bandit.*recommend", "exploration.*exploitation", "reward.*recommend", "online learn.*recommend"],
    "Embedding": ["embedding.*retrieval", "embedding.*model", "pre.train.*embedding", "item embedding", "user embedding", "product embedding", "sentence.*embedding"],
    "Attention Mechanism": ["attention mechanism", "self.attention.*model", "cross.attention.*model", "multi.head attention"],
}


def detect_knowledge_tags(paper):
    """Detect ML knowledge/technique tags from paper title and abstract."""
    title = paper.get("title", "").lower()
    abstract = paper.get("abstract", "").lower()
    text = title + " " + abstract

    found = []
    for tag, patterns in KNOWLEDGE_TAG_PATTERNS.items():
        for pattern in patterns:
            if re.search(pattern, text):
                found.append(tag)
                break

    # Limit to top 5 most specific tags (prefer less common ones)
    return found[:5]


def split_sentences(text):
    """Split text into sentences using regex."""
    sentences = re.split(r'(?<=[.!?])\s+', text.strip())
    return [s.strip() for s in sentences if len(s.strip()) > 15]


def generate_summary(paper):
    """Generate extractive summary from abstract."""
    abstract = paper.get("abstract", "")
    if not abstract:
        return ""

    sentences = split_sentences(abstract)
    if not sentences:
        return abstract[:300]

    scored = []
    important_phrases = [
        "we propose", "we present", "we introduce", "this paper",
        "our method", "our approach", "we show", "we demonstrate",
        "state-of-the-art", "outperform", "novel", "significantly",
        "achieve", "improve", "results show", "experiment",
    ]

    for i, sent in enumerate(sentences):
        score = 0
        lower = sent.lower()
        if i == 0: score += 3
        if i == len(sentences) - 1: score += 1
        for phrase in important_phrases:
            if phrase in lower: score += 2
        if any(c.isdigit() for c in sent): score += 1
        scored.append((score, i, sent))

    scored.sort(key=lambda x: x[0], reverse=True)
    top = sorted(scored[:3], key=lambda x: x[1])
    return " ".join(s[2] for s in top)


def generate_summary_bullets(paper):
    """
    Generate structured 3-bullet summary: Problem, Method, Result.
    """
    abstract = paper.get("abstract", "")
    if not abstract:
        return []

    sentences = split_sentences(abstract)
    if not sentences:
        return []

    problem_signals = [
        "challenge", "problem", "limitation", "gap", "however", "despite",
        "difficult", "remains", "lack", "bottleneck", "issue", "suffer",
        "crucial", "important", "essential", "critical", "fundamental",
    ]
    method_signals = [
        "we propose", "we present", "we introduce", "we design",
        "our method", "our approach", "our framework", "our model",
        "novel", "architecture", "framework", "mechanism",
        "leverage", "incorporate", "integrate", "combine",
        "key idea", "contribution", "in this paper", "this paper", "this work",
    ]
    result_signals = [
        "achieve", "outperform", "state-of-the-art", "sota", "improve",
        "experiment", "demonstrate", "result", "show that", "surpass",
        "superior", "significant", "benchmark", "evaluation",
        "accuracy", "performance", "gain", "deployed", "production",
        "auc", "ndcg", "mrr", "recall", "precision", "ctr",
    ]

    def score_sent(sent, signals):
        lower = sent.lower()
        return sum(2 if sig in lower else 0 for sig in signals)

    problem_best = method_best = result_best = None
    pb_score = mb_score = rb_score = -1

    for i, sent in enumerate(sentences):
        ps = score_sent(sent, problem_signals) + (2 if i == 0 else 0)
        ms = score_sent(sent, method_signals)
        rs = score_sent(sent, result_signals) + (1 if i == len(sentences) - 1 else 0)

        if ps > pb_score: pb_score = ps; problem_best = sent
        if ms > mb_score: mb_score = ms; method_best = sent
        if rs > rb_score: rb_score = rs; result_best = sent

    bullets = []
    seen = set()
    for label, sent in [("problem", problem_best), ("method", method_best), ("result", result_best)]:
        if sent and sent not in seen:
            if len(sent) > 250: sent = sent[:247] + "..."
            bullets.append({"type": label, "text": sent})
            seen.add(sent)

    if len(bullets) < 3:
        for sent in sentences:
            if sent not in seen and len(bullets) < 3:
                if len(sent) > 250: sent = sent[:247] + "..."
                bullets.append({"type": "insight", "text": sent})
                seen.add(sent)

    return bullets


def fetch_papers_for_query(query, max_results=100, year_min=2020):
    """Fetch papers for a single query from Semantic Scholar."""
    papers = []
    offset = 0
    batch = min(max_results, 100)

    while offset < max_results:
        limit = min(batch, max_results - offset)
        params = urllib.parse.urlencode({
            "query": query,
            "offset": offset,
            "limit": limit,
            "fields": FIELDS,
            "year": f"{year_min}-",
        })
        url = f"{API_BASE}/paper/search?{params}"

        data = None
        for attempt in range(5):
            try:
                req = urllib.request.Request(url, headers={"User-Agent": "MLPaperExplorer/1.0"})
                with urllib.request.urlopen(req, timeout=30) as resp:
                    data = json.loads(resp.read().decode())
                break
            except urllib.error.HTTPError as e:
                if e.code == 429 and attempt < 4:
                    wait = 5 * (2 ** attempt)
                    print(f"      [RATE LIMITED] Waiting {wait}s (attempt {attempt+1})...")
                    time.sleep(wait)
                else:
                    print(f"      [WARN] HTTP {e.code} for query offset={offset}")
                    break
            except urllib.error.URLError as e:
                print(f"      [WARN] URL error: {e}")
                break
        if data is None:
            break

        batch_papers = data.get("data", [])
        if not batch_papers:
            break

        for p in batch_papers:
            if not p.get("title") or not p.get("abstract"):
                continue
            if p.get("year") and p["year"] < year_min:
                continue

            arxiv_id = (p.get("externalIds") or {}).get("ArXiv")
            paper_url = p.get("url", "")
            if arxiv_id:
                paper_url = f"https://arxiv.org/abs/{arxiv_id}"

            authors = [a.get("name", "") for a in (p.get("authors") or []) if a.get("name")]
            categories = p.get("fieldsOfStudy") or []

            source = "arxiv" if arxiv_id else "conference" if p.get("venue") else "other"

            papers.append({
                "title": p["title"],
                "abstract": p["abstract"],
                "authors": authors,
                "date": p.get("publicationDate") or f"{p.get('year', 2020)}-01-01",
                "year": p.get("year") or year_min,
                "venue": p.get("venue") or "",
                "source": source,
                "url": paper_url,
                "citations": p.get("citationCount") or 0,
                "influential_citations": p.get("influentialCitationCount") or 0,
                "categories": categories,
            })

        offset += limit
        time.sleep(4)

    return papers


def deduplicate(papers):
    """Remove duplicate papers by title, keeping the one with highest citations."""
    seen = {}
    for p in papers:
        key = p["title"].strip().lower()
        if key not in seen or p.get("citations", 0) > seen[key].get("citations", 0):
            seen[key] = p
    return list(seen.values())


def propagate_companies(papers):
    """Second pass: propagate company tags using author co-occurrence.

    If 2+ authors on a paper are known to work at the same company
    (from papers already tagged), tag that paper too.
    """
    from collections import defaultdict, Counter

    # Build author -> companies mapping from already-tagged papers
    author_company = defaultdict(set)
    for p in papers:
        for c in p.get("companies", []):
            for author in p.get("authors", []):
                author_company[author].add(c)

    # Propagate: for untagged papers, add company if 2+ authors match
    added = 0
    for p in papers:
        existing = set(p.get("companies", []))
        company_hits = Counter()
        for author in p.get("authors", []):
            for c in author_company.get(author, set()):
                if c not in existing:
                    company_hits[c] += 1
        new_companies = [c for c, count in company_hits.items() if count >= 2]
        if new_companies:
            p["companies"] = sorted(existing | set(new_companies))
            added += 1

    if added:
        print(f"  Company propagation: tagged {added} additional papers via author co-occurrence")


def enrich_papers(papers):
    """Re-compute scores, summaries, companies, and knowledge tags for existing papers."""
    for p in papers:
        p["score"] = compute_score(p)
        p["companies"] = detect_companies(p)
        p["knowledge_tags"] = detect_knowledge_tags(p)
        if not p.get("summary"):
            p["summary"] = generate_summary(p)
        if not p.get("summary_bullets"):
            p["summary_bullets"] = generate_summary_bullets(p)

    # Second pass: propagate companies via author co-occurrence
    propagate_companies(papers)

    return papers


def main():
    parser = argparse.ArgumentParser(description="Fetch Search/Rec/LLM papers from Semantic Scholar")
    parser.add_argument("--topics", nargs="+", default=None, help="Topic names to fetch (default: all)")
    parser.add_argument("--max-per-query", type=int, default=100, help="Max papers per search query")
    parser.add_argument("--output", default="papers.json", help="Output JSON file")
    parser.add_argument("--year-min", type=int, default=2020, help="Minimum year")
    parser.add_argument("--append", action="store_true", help="Append to existing papers.json")
    parser.add_argument("--enrich", action="store_true", help="Re-compute scores/summaries only")
    args = parser.parse_args()

    all_papers = []

    # Load existing data
    if args.append:
        try:
            with open(args.output) as f:
                all_papers = json.load(f)
            print(f"Loaded {len(all_papers)} existing papers")
        except FileNotFoundError:
            pass

    if args.enrich:
        try:
            with open(args.output) as f:
                all_papers = json.load(f)
        except FileNotFoundError:
            print("No papers.json found")
            return
        print(f"Enriching {len(all_papers)} papers...")
        all_papers = enrich_papers(all_papers)
    else:
        # Determine which topics to fetch
        topics_to_fetch = DEFAULT_TOPICS
        if args.topics:
            topics_to_fetch = {k: v for k, v in DEFAULT_TOPICS.items() if k in args.topics}

        existing_topics = set()
        if args.append:
            existing_topics = {p.get("topic") for p in all_papers}

        topic_list = list(topics_to_fetch.items())
        total_queries = sum(len(queries) for _, queries in topic_list)
        query_num = 0

        for topic_name, queries in topic_list:
            if args.append and topic_name in existing_topics:
                query_num += len(queries)
                print(f"  Skipping topic: {topic_name} (already fetched)")
                continue

            print(f"\n=== {topic_name} ===")
            topic_papers = []

            for query in queries:
                query_num += 1
                print(f"  [{query_num}/{total_queries}] {query}")
                papers = fetch_papers_for_query(query, args.max_per_query, args.year_min)
                # Assign topic
                for p in papers:
                    p["topic"] = topic_name
                    p["score"] = compute_score(p)
                    p["companies"] = detect_companies(p)
                    p["knowledge_tags"] = detect_knowledge_tags(p)
                    p["summary"] = generate_summary(p)
                    p["summary_bullets"] = generate_summary_bullets(p)
                topic_papers.extend(papers)
                print(f"    -> {len(papers)} papers")
                time.sleep(5)

            print(f"  Topic total: {len(topic_papers)} papers")
            all_papers.extend(topic_papers)

    all_papers = deduplicate(all_papers)
    all_papers.sort(key=lambda p: (p.get("score", 0), p.get("citations", 0)), reverse=True)

    with open(args.output, "w") as f:
        json.dump(all_papers, f)

    print(f"\n{'='*50}")
    print(f"Total unique papers: {len(all_papers)}")
    print(f"Saved to {args.output}")

    by_topic = {}
    for p in all_papers:
        t = p.get("topic", "?")
        by_topic[t] = by_topic.get(t, 0) + 1
    print(f"\nBy topic:")
    for t, c in sorted(by_topic.items(), key=lambda x: -x[1]):
        print(f"  {t}: {c}")

    by_year = {}
    for p in all_papers:
        by_year[p.get("year", "?")] = by_year.get(p.get("year", "?"), 0) + 1
    print(f"\nBy year:")
    for y in sorted(by_year.keys()):
        print(f"  {y}: {by_year[y]}")


if __name__ == "__main__":
    main()
