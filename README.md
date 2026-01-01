# My Journal App

This is a monorepo containing both the Flutter frontend and the FastAPI backend.

## Structure

- **frontend/**: Flutter application (Mobile/Web/Desktop)
- **backend/**: FastAPI application (Python)

## Getting Started

### Frontend
```bash
cd frontend
flutter run
```

### Backend
```bash
cd backend
# Create/Activate virtual environment
# python -m venv venv
# .\venv\Scripts\activate
pip install -r requirements.txt
uvicorn main:app --reload
```
