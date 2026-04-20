from sqlalchemy import create_engine, text
import os
import sys
from dotenv import load_dotenv

# Add parent directory to path to import database (if needed, but we use .env here)
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL")
if not DATABASE_URL:
    # Fallback or error
    print("DATABASE_URL not found, checking if we can import it")
    from database import DATABASE_URL

def fix_schema():
    print(f"Connecting to database...")
    engine = create_engine(DATABASE_URL)
    with engine.connect() as conn:
        # 1. Add username
        try:
            print("Adding 'username' column...")
            conn.execute(text("ALTER TABLE users ADD COLUMN username VARCHAR UNIQUE;"))
            conn.commit()
            print("✅ Added 'username'")
        except Exception as e:
            print(f"⚠️ Could not add 'username' (might exist): {e}")

        # 2. Add bio
        try:
            print("Adding 'bio' column...")
            conn.execute(text("ALTER TABLE users ADD COLUMN bio VARCHAR;"))
            conn.commit()
            print("✅ Added 'bio'")
        except Exception as e:
            print(f"⚠️ Could not add 'bio' (might exist): {e}")

        # 3. Add is_focusing
        try:
            print("Adding 'is_focusing' column...")
            conn.execute(text("ALTER TABLE users ADD COLUMN is_focusing BOOLEAN DEFAULT FALSE;"))
            conn.commit()
            print("✅ Added 'is_focusing'")
        except Exception as e:
            print(f"⚠️ Could not add 'is_focusing' (might exist): {e}")

if __name__ == "__main__":
    fix_schema()
