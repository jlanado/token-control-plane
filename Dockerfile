FROM python:3.12-slim

WORKDIR /app

# deps first for layer caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# app code (control_plane is imported by gateway)
COPY control_plane.py gateway.py demo.py ./

EXPOSE 8000

# COMPRESSION_ON is set in gateway.py; override via env if you wire it up
CMD ["uvicorn", "gateway:app", "--host", "0.0.0.0", "--port", "8000"]
