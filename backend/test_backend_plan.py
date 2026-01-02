import requests
import json
import os

# Try local URL
url = "http://127.0.0.1:8000/ai/plan-today"

payload = {
    "day_start": "09:00",
    "planned_minutes": 240,
    "categories": ["Health", "Work"]
}

try:
    print(f"Sending request to {url}...")
    # Access token not strictly needed for the logic test if I mocked get_current_user or if I interpret the response 
    # BUT, the endpoint requires auth: current_user: User = Depends(get_current_user)
    # This makes testing hard without a token.
    
    # However, I can check if the backend is even UP.
    resp = requests.get("http://127.0.0.1:8000/")
    print(f"Root check: {resp.status_code}")
    
    # Login to get token first?
    # Or I can just check the logs.
    
    # Let's try to just hit the endpoint and see if we get 401 (Auth required) or Connection Refused.
    resp = requests.post(url, json=payload)
    print(f"Response Code: {resp.status_code}")
    print(f"Response Body: {resp.text}")

except Exception as e:
    print(f"Failed: {e}")
