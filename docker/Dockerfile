# Use multi-stage for smaller final image
FROM python:3.9-slim AS builder

WORKDIR /app
COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

FROM python:3.9-slim
WORKDIR /app

# Install system dependencies only
RUN apt-get update && apt-get install -y \
    sqlite3 \
    && rm -rf /var/lib/apt/lists/*

# Copy Python packages from builder
COPY --from=builder /root/.local /root/.local
ENV PATH=/root/.local/bin:$PATH

# Copy ONLY the evaluator
COPY evaluator.py /app/

# Create non-root user for security
RUN useradd -m -u 1000 runner
USER runner

ENTRYPOINT ["python", "/app/evaluator.py"]