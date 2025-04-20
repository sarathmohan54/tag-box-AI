#!/bin/bash
set -e

echo "Waiting for database..."
while ! pg_isready -h db -p 5432 -U myuser; do
    sleep 1
done

echo "Database is ready!"

echo "Initializing database..."
python -c "import models; import database; database.init_db()"

echo "Starting FastAPI application..."
exec uvicorn main:app --host 0.0.0.0 --port 8000 --reload --log-level debug 