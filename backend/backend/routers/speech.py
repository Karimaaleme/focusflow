from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
import os
import json
from datetime import datetime

from auth import get_current_user
from models import User

router = APIRouter(prefix="/speech", tags=["Speech"])


class SpeechRequest(BaseModel):
    text: str


def _get_openai_client():
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        return None
    try:
        from openai import OpenAI
        return OpenAI(api_key=api_key)
    except Exception:
        return None


@router.post("/to-task")
async def speech_to_task(
    req: SpeechRequest,
    current_user: User = Depends(get_current_user),
):
    if not req.text.strip():
        raise HTTPException(status_code=400, detail="Speech text is empty")

    client = _get_openai_client()
    if not client:
        raise HTTPException(status_code=503, detail="AI service unavailable. Check OPENAI_API_KEY.")

    today = datetime.now().strftime("%Y-%m-%d")
    now_iso = datetime.now().isoformat()

    system_prompt = f"""You are a task extraction assistant embedded in a productivity app.
Extract a structured task from the user's spoken input. The input may be in English or Hebrew — handle both.

Current date/time: {now_iso}

Return a JSON object with exactly these fields:
- "title" (string, required): concise, clear task title — always write in the same language as the input
- "description" (string): additional context or details in the same language, empty string if none
- "priority" (string): "low", "medium", or "high" — infer from urgency words (e.g. "urgent"/"דחוף" = high; "whenever"/"מתי שיהיה" = low), default "medium"
- "category" (string): one of "Work", "Study", "Health", "Personal", "Finance", "General" — infer from context
- "estimated_minutes" (integer): estimated duration in minutes, default 30
- "due_datetime" (string or null): ISO 8601 datetime ONLY if the user explicitly mentioned a time/date (e.g. "tomorrow", "Friday", "at 3pm", "מחר", "ביום שישי"). Resolve relative to {today}. If no time was mentioned set to null.
- "suggested_due_datetime" (string): your best suggestion for when this task should be done, ALWAYS set this even when due_datetime is null. Base it on task type and priority: urgent/high priority → today or tomorrow morning; study/exam → 2-3 days; health/personal → this week; shopping/errands → tomorrow; low priority → next week. Format as ISO 8601. Time should be reasonable (e.g. 09:00 for morning tasks, 18:00 for evening errands).
- "suggestion_reason" (string): one short sentence explaining why you picked that date (in the same language as the input, max 10 words)

Return ONLY the JSON object. No explanation, no markdown."""

    try:
        response = client.chat.completions.create(
            model=os.getenv("OPENAI_MODEL", "gpt-4o"),
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": req.text},
            ],
            response_format={"type": "json_object"},
            temperature=0.2,
        )
        result = json.loads(response.choices[0].message.content)

        # Sanitize fields
        result.setdefault("title", "New Task")
        result.setdefault("description", "")
        result.setdefault("priority", "medium")
        result.setdefault("category", "General")
        result.setdefault("estimated_minutes", 30)
        result.setdefault("due_datetime", None)

        if result["priority"] not in ("low", "medium", "high"):
            result["priority"] = "medium"

        return result

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to parse speech: {str(e)}")
