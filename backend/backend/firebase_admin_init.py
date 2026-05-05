import os
import json
import firebase_admin
from firebase_admin import credentials

if not firebase_admin._apps:
    key_json = os.getenv("FIREBASE_KEY_JSON", "").strip()
    key_path = os.getenv("FIREBASE_KEY_PATH", "").strip()

    if key_json:
        try:
            key_dict = json.loads(key_json)
            cred = credentials.Certificate(key_dict)
            print("[OK] Firebase initialized from FIREBASE_KEY_JSON env var")
        except json.JSONDecodeError as e:
            print(f"[ERROR] JSON parse failed: {e}")
            raise
    elif key_path and os.path.exists(key_path):
        cred = credentials.Certificate(key_path)
        print(f"[OK] Firebase initialized from FIREBASE_KEY_PATH: {key_path}")
    else:
        print("[WARN] Neither FIREBASE_KEY_JSON nor a valid FIREBASE_KEY_PATH is set")
        raise RuntimeError(
            "Firebase credentials not found. Set FIREBASE_KEY_JSON (Railway) "
            "or FIREBASE_KEY_PATH (local) in your .env file."
        )

    firebase_admin.initialize_app(cred)
