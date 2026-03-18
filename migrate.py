"""
PostgreSQL migration script for OMA Lightspeed.

This script connects to a PostgreSQL database and performs migrations.

This is because lightspeed-stack does not currently perform migrations on its own,
which means the database either has to be created from scratch or migrated like we do here.

Any migrations added should be idempotent, meaning they can be ran multiple times without
causing errors or unintended effects. This is because we run this script every time the
service starts to ensure the database is up to date.

Currently the migrations are as follows:

1. Add a new column `topic_summary` as it was added in lightspeed-stack v0.3.0

WARNING: This script assumes that the database is postgres and that the schema used is
called `lightspeed-stack`. If either of these assumptions are incorrect, the script may fail
or cause unintended effects. lightspeed-stack could also use sqlite or a different schema
if configured to do so, but we don't handle those cases here because we don't use them
in production.
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

# Wait for PostgreSQL to be ready (up to 60 seconds)
for attempt in range(30):
    try:
        conn = psycopg2.connect(
            host=os.getenv("OMA_POSTGRES_HOST"),
            port=os.getenv("OMA_POSTGRES_PORT"),
            dbname=os.getenv("OMA_POSTGRES_NAME"),
            user=os.getenv("OMA_POSTGRES_USER"),
            password=os.getenv("OMA_POSTGRES_PASSWORD"),
            sslmode=os.getenv("LIGHTSPEED_STACK_POSTGRES_SSL_MODE", "disable"),
        )
        break
    except psycopg2.OperationalError as e:
        print(f"Waiting for PostgreSQL... (attempt {attempt + 1}/30): {e}", file=sys.stderr)
        time.sleep(2)
else:
    sys.exit("PostgreSQL not available after 60 seconds")

# Check if lightspeed-stack schema exists (if not, it's a fresh database)
with conn.cursor() as cur:
    cur.execute(
        "SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'lightspeed-stack'"
    )
    if not cur.fetchone():
        print("Schema 'lightspeed-stack' not found - database is fresh, skipping migrations")
        conn.close()
        sys.exit(0)

# Run migrations (add new migrations here as needed)
cur = conn.cursor()

# Migration 1: Add topic_summary column (added in lightspeed-stack v0.3.0)
cur.execute(
    'ALTER TABLE "lightspeed-stack"."user_conversation" ADD COLUMN IF NOT EXISTS topic_summary text'
)

conn.commit()
cur.close()
conn.close()
print("Database migrations completed successfully")
