from database import engine, Base
from sqlalchemy import text

def run_migration():
    with engine.connect() as conn:
        conn.execution_options(isolation_level="AUTOCOMMIT")
        
        # 1. Add username column if not exists
        print("Checking if 'username' column exists in 'users' table...")
        try:
            conn.execute(text("ALTER TABLE users ADD COLUMN username VARCHAR UNIQUE"))
            print("✅ Added 'username' column to 'users' table.")
        except Exception as e:
            if "duplicate column" in str(e).lower() or "already exists" in str(e).lower():
                print("⚠️ 'username' column already exists.")
            else:
                print(f"❌ Error adding column: {e}")

    # 2. Create new tables
    print("Creating new tables (if not exist)...")
    Base.metadata.create_all(bind=engine)
    print("✅ Tables created/verified.")

if __name__ == "__main__":
    from models import FocusGroup, GroupMember, Invitation # Import to register with Base
    run_migration()
