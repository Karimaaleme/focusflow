import os
import psycopg2
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL")
if not DATABASE_URL:
    print("Error: DATABASE_URL not found")
    exit(1)

try:
    print("Connecting to database...")
    conn = psycopg2.connect(DATABASE_URL)
    cur = conn.cursor()

    columns_to_add = [
        ("coins", "INTEGER DEFAULT 0"),
        ("xp", "INTEGER DEFAULT 0"),
        ("focus_score", "INTEGER DEFAULT 0"),
        ("current_streak", "INTEGER DEFAULT 0"),
        ("longest_streak", "INTEGER DEFAULT 0"),
        ("last_focus_date", "DATE"),
        ("achievements", "JSON DEFAULT '[]'::json"),
        ("forest_settings", "JSON DEFAULT '{\"enabled\": true, \"sound\": true, \"strict\": false}'::json")
    ]

    for col_name, col_def in columns_to_add:
        try:
            cur.execute(f"ALTER TABLE user_profiles ADD COLUMN {col_name} {col_def};")
            print(f"Added '{col_name}' column to user_profiles")
        except psycopg2.errors.DuplicateColumn:
            print(f"Column '{col_name}' already exists, skipping...")
            conn.rollback()
        else:
            conn.commit()

    cur.close()
    conn.close()
    print("Advanced gamification migration completed successfully!")

except Exception as e:
    print(f"Failed to run migration: {e}")
