# Pod Labeler - Pre-built image for faster startup
# Build: docker build -t your-registry/pod-labeler:v1.0.0 .
FROM python:3.11-slim-bookworm

LABEL maintainer="postgres-cluster"
LABEL description="Pod labeler for PostgreSQL HA cluster"

# Install dependencies at build time (not runtime!)
RUN pip install --no-cache-dir psycopg2-binary kubernetes

# Create non-root user
RUN groupadd -r labeler -g 101 && \
    useradd -r -u 101 -g labeler labeler

# Copy the labeler script
COPY labeler.py /app/labeler.py

# Set ownership
RUN chown -R labeler:labeler /app

# Switch to non-root user
USER labeler

WORKDIR /app

# Run the labeler
CMD ["python", "-u", "/app/labeler.py"]

