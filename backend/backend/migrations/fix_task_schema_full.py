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
            # Add missing columns
            print("Adding missing columns to tasks...")
            
            # recurrence_interval
            try:
                conn.execute(text("ALTER TABLE tasks ADD COLUMN recurrence_interval INTEGER;"))
                print("✅ Added 'recurrence_interval'")
            except Exception as e:
                print(f"⚠️ recurrence_interval: {e}")

            # estimated_minutes
            try:
                conn.execute(text("ALTER TABLE tasks ADD COLUMN estimated_minutes INTEGER DEFAULT 30;"))
                print("✅ Added 'estimated_minutes'")
            except Exception as e:
                print(f"⚠️ estimated_minutes: {e}")

            # actual_minutes
            try:
                conn.execute(text("ALTER TABLE tasks ADD COLUMN actual_minutes INTEGER DEFAULT 0;"))
                print("✅ Added 'actual_minutes'")
            except Exception as e:
                print(f"⚠️ actual_minutes: {e}")

            # status
            try:
                conn.execute(text("ALTER TABLE tasks ADD COLUMN status VARCHAR DEFAULT 'todo';"))
                print("✅ Added 'status'")
            except Exception as e:
                print(f"⚠️ status: {e}")

            # order_index
            try:
                conn.execute(text("ALTER TABLE tasks ADD COLUMN order_index INTEGER DEFAULT 0;"))
                print("✅ Added 'order_index'")
            except Exception as e:
                print(f"⚠️ order_index: {e}")

            # subtasks
            try:
                conn.execute(text("ALTER TABLE tasks ADD COLUMN subtasks JSON DEFAULT '[]';"))
                print("✅ Added 'subtasks'")
            except Exception as e:
                print(f"⚠️ subtasks: {e}")

            conn.commit()
            print("✅ Migration Complete")
        except Exception as e:
            print(f"❌ Migration Failed: {e}")

if __name__ == "__main__":
    migrate()
