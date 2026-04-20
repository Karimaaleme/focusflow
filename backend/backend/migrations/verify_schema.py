from sqlalchemy import create_engine, inspect
import os
from dotenv import load_dotenv

load_dotenv()
DATABASE_URL = os.getenv("DATABASE_URL")

def verify():
    if not DATABASE_URL:
        print("DATABASE_URL not found!")
        return

    print(f"Connecting to {DATABASE_URL.split('@')[-1] if '@' in DATABASE_URL else 'DB'}...")
    engine = create_engine(DATABASE_URL)
    insp = inspect(engine)
    if not insp.has_table("users"):
        print("Table 'users' does not exist!")
        return
        
    columns = {c['name']: c for c in insp.get_columns('user_profiles')}
    print(f"Columns in 'user_profiles': {list(columns.keys())}")

    required = ['focus_style', 'main_struggle', 'best_time_of_day', 'motivation', 'theme_mode', 'accent_color', 'layout_density']
    missing = [c for c in required if c not in columns]
    
    if missing:
        print(f"❌ Missing columns: {missing}")
    else:
        print("✅ All required columns present.")

if __name__ == "__main__":
    verify()
