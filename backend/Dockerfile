# Use the official Python image from the Docker Hub
FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Set the working directory in the container
WORKDIR /app

# Copy the requirements file into the container
COPY requirements.txt .

# Install the dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Set environment variables
ENV PYTHONPATH=/app
ENV PYTHONUNBUFFERED=1

# Create and set permissions for the startup script
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
echo "Waiting for database..."\n\
while ! pg_isready -h db -p 5432 -U myuser; do\n\
    sleep 1\n\
done\n\
\n\
echo "Database is ready!"\n\
\n\
echo "Initializing database..."\n\
python -c "import models; import database; database.init_db()"\n\
\n\
echo "Starting FastAPI application..."\n\
exec uvicorn main:app --host 0.0.0.0 --port 8000 --reload --log-level debug' > start.sh && \
    chmod 755 start.sh

# Copy the application code
COPY . .

# Make port 8000 available to the world outside this container
EXPOSE 8000

# Run the startup script
ENTRYPOINT ["/bin/bash", "start.sh"] 