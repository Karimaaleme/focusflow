import sys
import os
from sqlalchemy import text

# Add project root so "database" can be imported
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from database import engine

print("🔧 Adding subtasks column to tasks table...")

with engine.connect() as conn:
    conn.execute(
        text(
            "ALTER TABLE tasks "
            "ADD COLUMN IF NOT EXISTS subtasks JSONB DEFAULT '[]'::jsonb"
        )
    )
    conn.commit()

print("✅ Migration done.")
