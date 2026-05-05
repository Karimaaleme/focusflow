# My Journal App

This is a monorepo containing both the Flutter frontend and the FastAPI backend.

## Structure

- **frontend/**: Flutter application (Mobile/Web/Desktop)
- **backend/**: FastAPI application (Python)

## Getting Started

### Quick Start (Windows)
To run both the backend and frontend simultaneously, simply execute the `run_project.bat` script from the root directory:
```bash
.\run_project.bat
```
This will launch the backend and frontend in separate command windows. Use the following URLs to access the application:

- **Frontend (Web App):** Automatically opens in your default browser (usually `http://localhost:<random-port>`).
- **Backend (API):** `http://127.0.0.1:8000/docs` (Interactive API Documentation)

### Manual Setup

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
