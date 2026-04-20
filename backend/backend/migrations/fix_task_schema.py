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
        # Add reminder_datetime
        try:
            print("Adding 'reminder_datetime' column to tasks...")
            conn.execute(text("ALTER TABLE tasks ADD COLUMN reminder_datetime TIMESTAMP;"))
            conn.commit()
            print("✅ Added 'reminder_datetime'")
        except Exception as e:
            print(f"⚠️ Could not add 'reminder_datetime' (might exist): {e}")

if __name__ == "__main__":
    migrate()
