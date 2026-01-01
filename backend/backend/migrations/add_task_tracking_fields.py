import sys
import os
from sqlalchemy import text

# Add project root so "database" can be imported
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from database import engine

print("🔧 Adding tracking fields to tasks table...")

with engine.connect() as conn:
    # 1. actual_minutes
    conn.execute(
        text(
            "ALTER TABLE tasks "
            "ADD COLUMN IF NOT EXISTS actual_minutes INTEGER DEFAULT 0"
        )
    )

    # 2. estimated_minutes (just in case, though likely exists)
    conn.execute(
        text(
            "ALTER TABLE tasks "
            "ADD COLUMN IF NOT EXISTS estimated_minutes INTEGER DEFAULT 30"
        )
    )
    
    conn.commit()

print("✅ Migration done.")
