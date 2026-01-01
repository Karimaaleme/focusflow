import sys
import os
from sqlalchemy import text

# Add project root so "database" can be imported
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from database import engine

print("🔧 Adding theme fields to user_profiles table...")

with engine.connect() as conn:
    # 1. theme_mode
    conn.execute(
        text(
            "ALTER TABLE user_profiles "
            "ADD COLUMN IF NOT EXISTS theme_mode VARCHAR DEFAULT 'system'"
        )
    )
    
    # 2. accent_color
    conn.execute(
        text(
            "ALTER TABLE user_profiles "
            "ADD COLUMN IF NOT EXISTS accent_color VARCHAR DEFAULT NULL"
        )
    )

    # 3. layout_density
    conn.execute(
        text(
            "ALTER TABLE user_profiles "
            "ADD COLUMN IF NOT EXISTS layout_density VARCHAR DEFAULT 'comfortable'"
        )
    )
    
    conn.commit()

print("✅ Migration done.")
