"""initial schema

Revision ID: 4a1e71f6f0af
Revises: 
Create Date: 2024-03-19 09:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '4a1e71f6f0af'
down_revision = None
branch_labels = None
depends_on = None


def upgrade():
    # Create users table
    op.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id SERIAL PRIMARY KEY,
            email VARCHAR NOT NULL UNIQUE,
            hashed_password VARCHAR NOT NULL,
            is_active BOOLEAN NOT NULL DEFAULT TRUE
        )
    """)

    # Create categories table
    op.execute("""
        CREATE TABLE IF NOT EXISTS categories (
            id SERIAL PRIMARY KEY,
            name VARCHAR NOT NULL,
            user_id INTEGER NOT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
        )
    """)

    # Create tags table
    op.execute("""
        CREATE TABLE IF NOT EXISTS tags (
            id SERIAL PRIMARY KEY,
            name VARCHAR NOT NULL UNIQUE,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
    """)

    # Create reels table
    op.execute("""
        CREATE TABLE IF NOT EXISTS reels (
            id SERIAL PRIMARY KEY,
            user_id INTEGER NOT NULL,
            category_id INTEGER,
            platform VARCHAR NOT NULL,
            reel_id VARCHAR NOT NULL,
            url VARCHAR NOT NULL,
            thumbnail_url VARCHAR NOT NULL,
            caption TEXT,
            author VARCHAR NOT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            reel_metadata JSONB,
            is_synced BOOLEAN NOT NULL DEFAULT TRUE,
            FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
            FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE SET NULL
        )
    """)

    # Create reel_tags table
    op.execute("""
        CREATE TABLE IF NOT EXISTS reel_tags (
            reel_id INTEGER NOT NULL,
            tag_id INTEGER NOT NULL,
            PRIMARY KEY (reel_id, tag_id),
            FOREIGN KEY (reel_id) REFERENCES reels (id) ON DELETE CASCADE,
            FOREIGN KEY (tag_id) REFERENCES tags (id) ON DELETE CASCADE
        )
    """)

    # Create indexes
    op.execute("""
        CREATE INDEX IF NOT EXISTS ix_users_email ON users (email);
        CREATE INDEX IF NOT EXISTS ix_reels_user_id ON reels (user_id);
        CREATE INDEX IF NOT EXISTS ix_reels_category_id ON reels (category_id);
        CREATE INDEX IF NOT EXISTS ix_reels_reel_id ON reels (reel_id);
        CREATE INDEX IF NOT EXISTS ix_tags_name ON tags (name);
    """)


def downgrade():
    # Drop tables in reverse order
    op.execute("""
        DROP TABLE IF EXISTS reel_tags CASCADE;
        DROP TABLE IF EXISTS reels CASCADE;
        DROP TABLE IF EXISTS tags CASCADE;
        DROP TABLE IF EXISTS categories CASCADE;
        DROP TABLE IF EXISTS users CASCADE;
    """) 