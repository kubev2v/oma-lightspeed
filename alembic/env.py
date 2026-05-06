"""
Alembic environment configuration for OMA Lightspeed.

Constructs the database URL from OMA_POSTGRES_* environment variables
and runs migrations against the 'lightspeed-stack' schema.
"""

import os
from logging.config import fileConfig

from alembic import context
from sqlalchemy import create_engine, text

config = context.config
if config.config_file_name is not None:
    fileConfig(config.config_file_name)


def get_database_url() -> str:
    """Build PostgreSQL URL from OMA_POSTGRES_* env vars."""
    host = os.environ["OMA_POSTGRES_HOST"]
    port = os.getenv("OMA_POSTGRES_PORT", "5432")
    name = os.getenv("OMA_POSTGRES_NAME", "oma_lightspeed")
    user = os.getenv("OMA_POSTGRES_USER", "oma")
    password = os.getenv("OMA_POSTGRES_PASSWORD", "")
    sslmode = os.getenv("LIGHTSPEED_STACK_POSTGRES_SSL_MODE", "disable")
    return f"postgresql://{user}:{password}@{host}:{port}/{name}?sslmode={sslmode}"


def run_migrations_online() -> None:
    """Run migrations in 'online' mode with a live database connection."""
    connectable = create_engine(get_database_url())

    with connectable.connect() as connection:
        # Only run migrations if the lightspeed-stack schema exists
        result = connection.execute(
            text(
                "SELECT schema_name FROM information_schema.schemata "
                "WHERE schema_name = 'lightspeed-stack'"
            )
        )
        if not result.fetchone():
            print(
                "Schema 'lightspeed-stack' not found - database is fresh, "
                "skipping migrations"
            )
            return

        context.configure(
            connection=connection,
            target_metadata=None,
            version_table_schema="lightspeed-stack",
        )

        with context.begin_transaction():
            context.run_migrations()


run_migrations_online()
