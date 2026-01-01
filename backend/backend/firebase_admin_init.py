import firebase_admin
from firebase_admin import credentials

import os

# 🔐 Path to your service account key
# Get the absolute path to the project root (one level up from this file)
current_dir = os.path.dirname(os.path.abspath(__file__))
project_root = os.path.dirname(current_dir)
key_path = os.path.join(project_root, "firebase_key.json")

cred = credentials.Certificate(key_path)

# ✅ Initialize ONLY ONCE
if not firebase_admin._apps:
    firebase_admin.initialize_app(cred)
