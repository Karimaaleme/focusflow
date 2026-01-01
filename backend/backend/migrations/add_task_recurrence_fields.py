import sys
import os
from sqlalchemy import text

# Add project root so "database" can be imported
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from database import engine

print("🔧 Adding recurrence fields to tasks table...")

with engine.connect() as conn:
    # 1. is_recurring
    conn.execute(
        text(
            "ALTER TABLE tasks "
            "ADD COLUMN IF NOT EXISTS is_recurring BOOLEAN DEFAULT FALSE"
        )
    )

    # 2. recurrence
    conn.execute(
        text(
            "ALTER TABLE tasks "
            "ADD COLUMN IF NOT EXISTS recurrence VARCHAR DEFAULT NULL"
        )
    )

    # 3. recurrence_interval
    conn.execute(
        text(
            "ALTER TABLE tasks "
            "ADD COLUMN IF NOT EXISTS recurrence_interval INTEGER DEFAULT NULL"
        )
    )
    
    conn.commit()

print("✅ Migration done.")
