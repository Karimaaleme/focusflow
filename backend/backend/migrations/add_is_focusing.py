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
            # Postgres syntax often supports IF NOT EXISTS, but generic is fine with try/catch
            conn.execute(text("ALTER TABLE users ADD COLUMN is_focusing BOOLEAN DEFAULT FALSE"))
            conn.commit()
            print("Successfully added is_focusing column")
        except Exception as e:
            print(f"Migration result (might be safe if column exists): {e}")

if __name__ == "__main__":
    migrate()
