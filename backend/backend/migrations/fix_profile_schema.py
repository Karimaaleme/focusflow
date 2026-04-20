from sqlalchemy import create_engine, text
import os
import sys
from dotenv import load_dotenv

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
load_dotenv()
DATABASE_URL = os.getenv("DATABASE_URL")
if not DATABASE_URL:
    from database import DATABASE_URL

def migrate():
    print(f"Connecting to DB...")
    engine = create_engine(DATABASE_URL)
    with engine.connect() as conn:
        cols = [
            "focus_style VARCHAR",
            "main_struggle VARCHAR",
            "best_time_of_day VARCHAR",
            "motivation VARCHAR",
            "theme VARCHAR",
            "theme_mode VARCHAR DEFAULT 'system'",
            "accent_color VARCHAR",
            "layout_density VARCHAR DEFAULT 'comfortable'"
        ]
        
        for col_def in cols:
            try:
                col_name = col_def.split()[0]
                print(f"Adding '{col_name}'...")
                conn.execute(text(f"ALTER TABLE user_profiles ADD COLUMN {col_def};"))
                conn.commit()
                print(f"✅ Added '{col_name}'")
            except Exception as e:
                print(f"⚠️ Could not add '{col_name}' (might exist): {e}")

if __name__ == "__main__":
    migrate()
