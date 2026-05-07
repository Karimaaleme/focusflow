import os
import psycopg2
from dotenv import load_dotenv

load_dotenv()

# Get DB URL
DATABASE_URL = os.getenv("DATABASE_URL")
if not DATABASE_URL:
    print("Error: DATABASE_URL not found in environment variables")
    exit(1)

try:
    print(f"Connecting to database...")
    conn = psycopg2.connect(DATABASE_URL)
    cur = conn.cursor()
    
    # 1. Add plant_type
    try:
        cur.execute("ALTER TABLE focus_sessions ADD COLUMN plant_type VARCHAR;")
        print("Added 'plant_type' column to focus_sessions table")
    except psycopg2.errors.DuplicateColumn:
        print("Column 'plant_type' already exists, skipping...")
        conn.rollback()
    else:
        conn.commit()

    # 2. Add is_successful
    try:
        cur.execute("ALTER TABLE focus_sessions ADD COLUMN is_successful BOOLEAN DEFAULT FALSE;")
        print("Added 'is_successful' column to focus_sessions table")
    except psycopg2.errors.DuplicateColumn:
        print("Column 'is_successful' already exists, skipping...")
        conn.rollback()
    else:
        conn.commit()
        
    cur.close()
    conn.close()
    print("Migration completed successfully!")
    
except Exception as e:
    print(f"Failed to run migration: {e}")
