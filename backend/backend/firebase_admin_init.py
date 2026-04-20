import os
import json
import firebase_admin
from firebase_admin import credentials

if not firebase_admin._apps:
    key_json = os.getenv("FIREBASE_KEY_JSON")
    if key_json:
        # Production: key content stored as env variable
        key_dict = json.loads(key_json)
        cred = credentials.Certificate(key_dict)
    else:
        # Local dev: key file on disk
        current_dir = os.path.dirname(os.path.abspath(__file__))
        project_root = os.path.dirname(current_dir)
        key_path = os.path.join(project_root, "firebase_key.json")
        cred = credentials.Certificate(key_path)

    firebase_admin.initialize_app(cred)
