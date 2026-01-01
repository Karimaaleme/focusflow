# create_tables.py
from database import Base, engine

# 👉 IMPORTANT: import all models so SQLAlchemy sees them
from models import User, Task, UserProfile

print("🔨 Creating tables...")
Base.metadata.create_all(bind=engine)
print("✅ Tables created successfully.")
