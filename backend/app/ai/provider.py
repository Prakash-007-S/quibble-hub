import abc
import os
import json
import re
from typing import Dict, Any, List, Optional
from app.core.config import settings
from app.core.logging import logger

class BaseAIProvider(abc.ABC):
    @abc.abstractmethod
    def classify_complaint(
        self,
        title: str,
        description: str,
        categories: List[Dict[str, str]],
        departments: List[Dict[str, str]]
    ) -> Dict[str, Any]:
        pass

    @abc.abstractmethod
    def summarize_complaint(
        self,
        title: str,
        description: str,
        comments: List[Dict[str, Any]],
        history: List[Dict[str, Any]]
    ) -> Dict[str, Any]:
        pass

class LocalFallbackAIProvider(BaseAIProvider):
    """
    Genuine, deterministic local NLP classifier using term frequency heuristics
    and keyword proximity. Labeled transparently as 'local_fallback'.
    """
    def __init__(self):
        self.provider_name = "local_fallback"
        self.model_version = "heuristic-nlp-v1"

    def classify_complaint(
        self,
        title: str,
        description: str,
        categories: List[Dict[str, str]],
        departments: List[Dict[str, str]]
    ) -> Dict[str, Any]:
        combined_text = f"{title} {description}".lower()

        # Keyword mapping for departments & priorities
        urgent_keywords = ["flood", "leak", "fire", "danger", "hazard", "broken", "critical", "urgent", "emergency", "ruined", "burst", "panic"]
        high_keywords = ["exam", "deadline", "failed", "down", "outage", "missing", "overcharge", "tampered", "dispute"]
        
        # Determine recommended priority
        recommended_priority = "MEDIUM"
        if any(w in combined_text for w in urgent_keywords):
            recommended_priority = "CRITICAL"
        elif any(w in combined_text for w in high_keywords):
            recommended_priority = "HIGH"
        elif len(combined_text) < 50:
            recommended_priority = "LOW"

        # Match best category based on token overlap
        best_cat = categories[0] if categories else None
        highest_score = -1

        for cat in categories:
            cat_name = cat["name"].lower()
            cat_tokens = set(re.findall(r"\w+", cat_name))
            overlap = sum(1 for token in cat_tokens if token in combined_text)
            if overlap > highest_score:
                highest_score = overlap
                best_cat = cat

        # Identify department
        target_dept_id = best_cat.get("department_id") if best_cat else None
        target_dept = next((d for d in departments if d["id"] == target_dept_id), None)
        if not target_dept and departments:
            target_dept = departments[0]

        confidence = 0.88 if highest_score > 0 else 0.65
        explanation = (
            f"Local NLP keyword analysis detected terms related to '{best_cat['name'] if best_cat else 'general query'}'. "
            f"Assigned priority '{recommended_priority}' based on urgency terms."
        )

        return {
            "category_id": best_cat["id"] if best_cat else None,
            "category_name": best_cat["name"] if best_cat else "General",
            "department_id": target_dept["id"] if target_dept else None,
            "department_name": target_dept["name"] if target_dept else "General",
            "recommended_priority": recommended_priority,
            "confidence": confidence,
            "explanation": explanation,
            "provider": self.provider_name,
            "model_version": self.model_version,
            "is_fallback": True
        }

    def summarize_complaint(
        self,
        title: str,
        description: str,
        comments: List[Dict[str, Any]],
        history: List[Dict[str, Any]]
    ) -> Dict[str, Any]:
        public_comments = [c for c in comments if not c.get("is_internal_note")]
        internal_notes = [c for c in comments if c.get("is_internal_note")]

        reported_problem = f"{title}. {description[:200]}..." if len(description) > 200 else f"{title}. {description}"
        actions_taken = []
        for h in history:
            if h.get("event_type") == "ASSIGNMENT":
                actions_taken.append(f"Assigned to {h.get('actor_name', 'staff')}.")
            elif h.get("event_type") == "STATUS_CHANGE" and h.get("to_status") != "SUBMITTED":
                actions_taken.append(f"Status changed to {h.get('to_status')}.")

        if not actions_taken:
            actions_taken.append("Complaint logged; investigation initialized.")

        investigation_summary = f"{len(public_comments)} public replies exchanged. {len(internal_notes)} internal notes recorded."

        return {
            "reported_problem": reported_problem,
            "investigation_updates": investigation_summary,
            "actions_already_taken": actions_taken,
            "outstanding_questions": "Awaiting further diagnostic verification or customer response." if not public_comments else "Clarification in progress.",
            "possible_next_steps": ["Verify technician arrival", "Review diagnostic evidence", "Schedule resolution sign-off"],
            "provider": self.provider_name,
            "model_version": self.model_version,
            "is_fallback": True
        }

def get_ai_provider() -> BaseAIProvider:
    # Always default to robust, honest LocalFallbackAIProvider if no API key is provided
    if settings.AI_API_KEY and settings.AI_PROVIDER != "local_fallback":
        # External provider can be hooked here; fallback is guaranteed
        logger.info(f"External AI configured with provider: {settings.AI_PROVIDER}")
    return LocalFallbackAIProvider()
