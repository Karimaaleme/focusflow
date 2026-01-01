import sys
import os
from sqlalchemy import text

# Add project root so "database" can be imported
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from database import engine

print("🔧 Adding reminder_datetime to tasks table...")

with engine.connect() as conn:
    conn.execute(
        text(
            "ALTER TABLE tasks "
            "ADD COLUMN IF NOT EXISTS reminder_datetime TIMESTAMP WITH TIME ZONE DEFAULT NULL"
        )
    )
    conn.commit()

print("✅ Migration done.")
