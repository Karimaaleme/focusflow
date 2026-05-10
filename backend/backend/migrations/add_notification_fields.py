import sys, pathlib
from dotenv import load_dotenv
from sqlalchemy import text

_ROOT = pathlib.Path(__file__).parent.parent
sys.path.insert(0, str(_ROOT))
load_dotenv(dotenv_path=_ROOT.parent / ".env")

from database import engine

print("Adding notification fields to user_profiles table...")

with engine.connect() as conn:
    conn.execute(text(
        "ALTER TABLE user_profiles "
        "ADD COLUMN IF NOT EXISTS notifications_push BOOLEAN DEFAULT FALSE"
    ))
    conn.execute(text(
        "ALTER TABLE user_profiles "
        "ADD COLUMN IF NOT EXISTS notifications_email BOOLEAN DEFAULT FALSE"
    ))
    conn.execute(text(
        "ALTER TABLE user_profiles "
        "ADD COLUMN IF NOT EXISTS notifications_summary BOOLEAN DEFAULT FALSE"
    ))
    conn.commit()

print("Migration done.")
