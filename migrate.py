"""
PostgreSQL migration script for OMA Lightspeed.

This script waits for PostgreSQL to be ready, then runs Alembic migrations.

This is because lightspeed-stack does not currently perform migrations on its own,
which means the database either has to be created from scratch or migrated like we do here.

Migrations are managed via Alembic and live in alembic/versions/.

WARNING: This script assumes that the database is postgres and that the schema used is
called `lightspeed-stack`. If either of these assumptions are incorrect, the script may fail
or cause unintended effects. lightspeed-stack could also use sqlite or a different schema
if configured to do so, but we don't handle those cases here because we don't use them
in production.

Environment variables for connection retry behavior:
  OMA_POSTGRES_CONNECT_TIMEOUT       - total seconds to wait (default: 60)
  OMA_POSTGRES_CONNECT_RETRY_INTERVAL - initial retry interval in seconds (default: 2)
  Retry interval doubles on each attempt (exponential backoff), capped at 16 seconds.
"""

import os
import time
import sys

# Check if we're using PostgreSQL (production) or SQLite (local dev)
postgres_host = os.getenv("OMA_POSTGRES_HOST")
if not postgres_host:
    print("No PostgreSQL configured (OMA_POSTGRES_HOST not set), skipping migrations")
    sys.exit(0)

import psycopg2

# SSL configuration for PostgreSQL connection
ssl_params = {
    "sslmode": os.getenv("LIGHTSPEED_STACK_POSTGRES_SSL_MODE", "require"),
}

# Configurable connection retry settings
connect_timeout = int(os.getenv("OMA_POSTGRES_CONNECT_TIMEOUT", "60"))
retry_interval = float(os.getenv("OMA_POSTGRES_CONNECT_RETRY_INTERVAL", "2"))
max_interval = 16  # cap backoff at 16 seconds

# Wait for PostgreSQL to be ready with exponential backoff
elapsed = 0.0
attempt = 0
conn = None
while elapsed < connect_timeout:
    attempt += 1
    try:
        per_attempt_timeout = max(1, int(min(max_interval, connect_timeout - elapsed)))
        conn = psycopg2.connect(
            host=os.getenv("OMA_POSTGRES_HOST"),
            port=os.getenv("OMA_POSTGRES_PORT"),
            dbname=os.getenv("OMA_POSTGRES_NAME"),
            user=os.getenv("OMA_POSTGRES_USER"),
            password=os.getenv("OMA_POSTGRES_PASSWORD"),
            **ssl_params,
            connect_timeout=per_attempt_timeout,
        )
        break
    except psycopg2.OperationalError as e:
        current_interval = min(retry_interval * (2 ** (attempt - 1)), max_interval)
        remaining = connect_timeout - elapsed
        sleep_time = min(current_interval, remaining)
        print(
            f"Waiting for PostgreSQL... (attempt {attempt}, "
            f"{elapsed:.0f}s/{connect_timeout}s elapsed): {e}",
            file=sys.stderr,
        )
        if sleep_time <= 0:
            break
        time.sleep(sleep_time)
        elapsed += sleep_time

if conn is None:
    sys.exit(f"PostgreSQL not available after {connect_timeout} seconds")

conn.close()

# Run Alembic migrations
from alembic.config import Config
from alembic import command

alembic_cfg = Config("alembic.ini")
print("Running Alembic migrations...")
command.upgrade(alembic_cfg, "head")
print("Database migrations completed successfully")
