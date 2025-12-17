FROM python:3.9-slim

WORKDIR /app

# Install SQLite and other dependencies
RUN apt-get update && apt-get install -y sqlite3 && rm -rf /var/lib/apt/lists/*

# Copy scripts
COPY docker/entrypoint.sh /entrypoint.sh
COPY scripts/run_check.py /app/run_check.py
COPY check.py /app/check.py

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
