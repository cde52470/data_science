#!/bin/bash
set -e

echo "[start] Starting R Plumber API on port 8001..."
Rscript /app/run_plumber.R &

echo "[start] Waiting for R Plumber to be ready (RF training may take ~30s)..."
until curl -s http://127.0.0.1:8001 > /dev/null 2>&1; do
  sleep 3
done
echo "[start] R Plumber ready."

echo "[start] Starting FastAPI on port 8000..."
exec python3 -m uvicorn main:app --host 0.0.0.0 --port 8000
