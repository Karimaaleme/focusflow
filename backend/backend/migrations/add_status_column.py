import sys
import os
from sqlalchemy import text

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from database import engine

print("🔧 Adding status column to tasks (if missing)...")

with engine.connect() as conn:
    conn.execute(
        text("""
        ALTER TABLE tasks
        ADD COLUMN IF NOT EXISTS status VARCHAR DEFAULT 'todo';
    """)
    )
    conn.commit()

print("✅ Migration done.")
