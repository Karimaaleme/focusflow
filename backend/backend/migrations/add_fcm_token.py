import sys, pathlib
from dotenv import load_dotenv
from sqlalchemy import text

_ROOT = pathlib.Path(__file__).parent.parent
sys.path.insert(0, str(_ROOT))
load_dotenv(dotenv_path=_ROOT.parent / ".env")

from database import engine

print("Adding fcm_token column to users table...")
with engine.connect() as conn:
    conn.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS fcm_token VARCHAR DEFAULT NULL"))
    conn.commit()
print("Migration done.")
