import sys, os
from sqlalchemy import text
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database import engine

print("Adding fcm_token column to users table...")
with engine.connect() as conn:
    conn.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS fcm_token VARCHAR DEFAULT NULL"))
    conn.commit()
print("Migration done.")
