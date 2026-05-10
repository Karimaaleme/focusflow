import sys
import os
from sqlalchemy import text

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from database import engine

print("Adding notification fields to user_profiles table...")

with engine.connect() as conn:
    conn.execute(text(
        "ALTER TABLE user_profiles "
        "ADD COLUMN IF NOT EXISTS notifications_push BOOLEAN DEFAULT FALSE"
    ))
    conn.execute(text(
        "ALTER TABLE user_profiles "
        "ADD COLUMN IF NOT EXISTS notifications_email BOOLEAN DEFAULT FALSE"
    ))
    conn.execute(text(
        "ALTER TABLE user_profiles "
        "ADD COLUMN IF NOT EXISTS notifications_summary BOOLEAN DEFAULT FALSE"
    ))
    conn.commit()

print("Migration done.")
