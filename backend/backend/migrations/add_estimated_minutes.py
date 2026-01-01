import sys
import os
from sqlalchemy import text

# Add project root so "database" can be imported
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from database import engine

print("🔧 Adding estimated_minutes column to tasks (if missing)...")

with engine.connect() as conn:
    conn.execute(
        text(
            "ALTER TABLE tasks "
            "ADD COLUMN IF NOT EXISTS estimated_minutes INTEGER DEFAULT 30"
        )
    )
    conn.commit()

print("✅ Migration done.")
