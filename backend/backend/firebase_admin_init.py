import os
import json
import firebase_admin
from firebase_admin import credentials

if not firebase_admin._apps:
    key_json = os.getenv("FIREBASE_KEY_JSON", "").strip()
    print(f"🔑 FIREBASE_KEY_JSON set: {bool(key_json)}, length: {len(key_json)}")

    if key_json:
        try:
            key_dict = json.loads(key_json)
            cred = credentials.Certificate(key_dict)
            print("✅ Firebase initialized from environment variable")
        except json.JSONDecodeError as e:
            print(f"❌ JSON parse failed: {e}")
            raise
    else:
        print("⚠️  FIREBASE_KEY_JSON is empty — check Railway Variables tab")
        raise RuntimeError(
            "FIREBASE_KEY_JSON environment variable is not set. "
            "Add it in Railway → your service → Variables tab."
        )

    firebase_admin.initialize_app(cred)
