"""Create app_notifications table"""
import sys, pathlib
from dotenv import load_dotenv

_ROOT = pathlib.Path(__file__).parent.parent
sys.path.insert(0, str(_ROOT))
load_dotenv(dotenv_path=_ROOT.parent / ".env")

from database import engine
from sqlalchemy import text

with engine.connect() as conn:
    conn.execute(text("""
        CREATE TABLE IF NOT EXISTS app_notifications (
            id SERIAL PRIMARY KEY,
            user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            type VARCHAR NOT NULL DEFAULT 'system',
            title VARCHAR NOT NULL,
            body VARCHAR NOT NULL,
            is_read BOOLEAN NOT NULL DEFAULT FALSE,
            related_id INTEGER,
            created_at TIMESTAMP DEFAULT NOW()
        )
    """))
    conn.execute(text("CREATE INDEX IF NOT EXISTS ix_app_notifications_user_id ON app_notifications(user_id)"))
    conn.commit()

print("✅ app_notifications table created")
