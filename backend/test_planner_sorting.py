
import sys
import os
from datetime import datetime, timedelta

# Add backend to path so we can import
sys.path.append(os.path.join(os.getcwd(), 'backend'))

try:
    from backend.ai.ai_planner import _fallback_schedule
except ImportError:
    # If import fails, define strict mocks or copy function? 
    # Let's try to assume the structure matches user file system
    # If this fails, I will just copy the function for testing logic
    print("Could not import _fallback_schedule. Make sure you run this from 'c:\\Users\\97254\\my_journal_app\\backend'")
    sys.exit(1)

def test_sorting():
    today = datetime.now()
    tomorrow = today + timedelta(days=1)
    next_week = today + timedelta(days=7)
    
    tasks = [
        {
            "id": 1,
            "title": "Low Priority, Due Tomorrow",
            "priority": "low",
            "due_datetime": tomorrow.isoformat(),
            "estimated_minutes": 30
        },
        {
            "id": 2,
            "title": "High Priority, Due Next Week",
            "priority": "high",
            "due_datetime": next_week.isoformat(),
            "estimated_minutes": 30
        },
        {
            "id": 3,
            "title": "Medium Priority, Overdue",
            "priority": "medium",
            "due_datetime": (today - timedelta(days=1)).isoformat(),
            "estimated_minutes": 30
        },
        {
            "id": 4,
            "title": "High Priority, No Due Date",
            "priority": "high",
            "due_datetime": None,
            "estimated_minutes": 30
        }
    ]
    
    # Run fallback schedule
    result = _fallback_schedule(tasks, "09:00", 480)
    
    print("Scheduled Order:")
    for item in result['items']:
        print(f"- {item['title']}")

if __name__ == "__main__":
    test_sorting()
