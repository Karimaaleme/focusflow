"""Run all pending migrations in order. Safe to re-run (all use IF NOT EXISTS / IF NOT EXISTS)."""
import subprocess
import sys
import pathlib

MIGRATIONS_DIR = pathlib.Path(__file__).parent
PYTHON = sys.executable

ORDERED = [
    "add_status_column.py",
    "add_order_index_column.py",
    "add_estimated_minutes.py",
    "add_task_subtasks_column.py",
    "add_task_tracking_fields.py",
    "add_task_reminder_field.py",
    "add_task_recurrence_fields.py",
    "fix_user_schema.py",
    "fix_password_nullable.py",
    "fix_profile_schema.py",
    "fix_task_schema.py",
    "fix_task_schema_full.py",
    "add_user_profile_theme_fields.py",
    "add_user_bio.py",
    "add_is_focusing.py",
    "add_study_together_tables.py",
    "add_group_id_to_focus.py",
    "add_gamification_fields.py",
    "add_advanced_gamification.py",
    # New: notifications / push support
    "add_fcm_token.py",
    "add_notification_fields.py",
    "add_notifications_table.py",
]

def main():
    for name in ORDERED:
        path = MIGRATIONS_DIR / name
        if not path.exists():
            print(f"⚠️  SKIP (not found): {name}")
            continue
        print(f"▶ Running {name} …")
        result = subprocess.run([PYTHON, str(path)], capture_output=True, text=True)
        if result.stdout:
            print(result.stdout.rstrip())
        if result.returncode != 0:
            print(f"❌ FAILED: {name}\n{result.stderr}")
            sys.exit(1)
        else:
            print(f"✅ Done: {name}")

if __name__ == "__main__":
    main()
