from typing import List, Dict, Any
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity

def find_duplicate_candidates(
    target_title: str,
    target_description: str,
    existing_complaints: List[Dict[str, Any]],
    similarity_threshold: float = 0.30,
    top_k: int = 5
) -> List[Dict[str, Any]]:
    """
    Computes TF-IDF vector similarity between a new complaint and existing complaints
    within the same tenant organization.
    """
    if not existing_complaints:
        return []

    target_text = f"{target_title} {target_description}".strip()
    corpus = [target_text] + [f"{c['title']} {c['description']}".strip() for c in existing_complaints]

    # Stopwords english, bi-grams for phrase capture
    vectorizer = TfidfVectorizer(stop_words="english", ngram_range=(1, 2))
    try:
        tfidf_matrix = vectorizer.fit_transform(corpus)
    except Exception:
        # Fallback if vocabulary is too small
        vectorizer = TfidfVectorizer(ngram_range=(1, 1))
        tfidf_matrix = vectorizer.fit_transform(corpus)

    # Compute cosine similarity between target (index 0) and all existing (indices 1..)
    similarities = cosine_similarity(tfidf_matrix[0:1], tfidf_matrix[1:])[0]

    results = []
    for idx, score in enumerate(similarities):
        score_val = round(float(score), 3)
        if score_val >= similarity_threshold:
            match = existing_complaints[idx]
            results.append({
                "complaint_id": match["id"],
                "tracking_number": match["tracking_number"],
                "title": match["title"],
                "status": match["status"],
                "similarity_score": score_val,
                "confidence_label": "High Similarity" if score_val >= 0.65 else "Moderate Similarity"
            })

    # Sort descending by similarity
    results.sort(key=lambda x: x["similarity_score"], reverse=True)
    return results[:top_k]
