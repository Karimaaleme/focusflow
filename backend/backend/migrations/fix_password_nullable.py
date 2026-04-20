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
        try:
            print("Altering hashed_password to be nullable...")
            conn.execute(text("ALTER TABLE users ALTER COLUMN hashed_password DROP NOT NULL;"))
            conn.commit()
            print("✅ Successfully made hashed_password nullable.")
        except Exception as e:
            print(f"⚠️ Error (maybe column doesn't exist?): {e}")

if __name__ == "__main__":
    migrate()
