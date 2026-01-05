from sqlalchemy import create_engine, text
import os
from dotenv import load_dotenv

load_dotenv()

# Database URL
DATABASE_URL = os.getenv("DATABASE_URL")
if not DATABASE_URL:
    print("Error: DATABASE_URL not found in .env")
    exit(1)

def migrate():
    print(f"Connecting to database...")
    engine = create_engine(DATABASE_URL)
    with engine.connect() as conn:
        try:
            conn.execute(text("ALTER TABLE focus_sessions ADD COLUMN group_id INTEGER REFERENCES focus_groups(id)"))
            conn.commit()
            print("Successfully added group_id column")
        except Exception as e:
            print(f"Migration result: {e}")

if __name__ == "__main__":
    migrate()
