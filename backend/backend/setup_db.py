import psycopg2

connection = psycopg2.connect(
    host="localhost", user="karimaaleme", password="", port="5432", database="postgres"
)
3
connection.autocommit = True

with connection.cursor() as cur:
    # ---------- CREATE DATABASE IF NOT EXISTS ----------
    cur.execute("SELECT 1 FROM pg_database WHERE datname='focusflow';")
    exists = cur.fetchone()
    if not exists:
        cur.execute("CREATE DATABASE focusflow;")
        print("✅ Database 'focusflow' created.")
    else:
        print("⚠️ Database 'focusflow' already exists. Skipping creation.")

    # ---------- CREATE USER IF NOT EXISTS ----------
    cur.execute("SELECT 1 FROM pg_roles WHERE rolname='focusflow_user';")
    user_exists = cur.fetchone()
    if not user_exists:
        cur.execute("CREATE USER focusflow_user WITH PASSWORD 'yosef';")
        print("✅ User 'focusflow_user' created.")
    else:
        print("⚠️ User 'focusflow_user' already exists. Skipping creation.")

    # ---------- GRANT PRIVILEGES ----------
    cur.execute("GRANT ALL PRIVILEGES ON DATABASE focusflow TO focusflow_user;")
    print("🔑 Privileges ensured for 'focusflow_user'.")

connection.close()
print("🎉 Setup completed.")
