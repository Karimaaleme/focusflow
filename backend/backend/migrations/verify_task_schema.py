from sqlalchemy import create_engine, inspect
import os
import sys
from dotenv import load_dotenv

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL")
if not DATABASE_URL:
    from database import DATABASE_URL

def verify():
    engine = create_engine(DATABASE_URL)
    inspector = inspect(engine)
    columns = [col['name'] for col in inspector.get_columns('tasks')]
    print(f"Tasks Table Columns: {columns}")
    
    missing = []
    expected = ['reminder_datetime', 'category']
    for e in expected:
        if e not in columns:
            missing.append(e)
            
    if missing:
        print(f"❌ Missing columns: {missing}")
    else:
        print("✅ usage columns present")

if __name__ == "__main__":
    verify()
