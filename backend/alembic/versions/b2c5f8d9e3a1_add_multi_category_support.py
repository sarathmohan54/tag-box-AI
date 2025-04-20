"""add multi category support

Revision ID: b2c5f8d9e3a1
Revises: 4a1e71f6f0af
Create Date: 2024-03-19 10:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'b2c5f8d9e3a1'
down_revision = '4a1e71f6f0af'
branch_labels = None
depends_on = None


def upgrade():
    # Create reel_categories association table if it doesn't exist
    op.execute("""
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 
                FROM information_schema.tables 
                WHERE table_name = 'reel_categories'
            ) THEN
                CREATE TABLE reel_categories (
                    reel_id INTEGER NOT NULL,
                    category_id INTEGER NOT NULL,
                    PRIMARY KEY (reel_id, category_id),
                    FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE,
                    FOREIGN KEY (reel_id) REFERENCES reels (id) ON DELETE CASCADE
                );
            END IF;
        END $$;
    """)

    # Check if category_id column exists in reels table
    op.execute("""
        DO $$
        BEGIN
            IF EXISTS (
                SELECT 1 
                FROM information_schema.columns 
                WHERE table_name='reels' AND column_name='category_id'
            ) THEN
                -- Copy existing category relationships to the association table
                INSERT INTO reel_categories (reel_id, category_id)
                SELECT id, category_id 
                FROM reels 
                WHERE category_id IS NOT NULL
                ON CONFLICT DO NOTHING;

                -- Create temporary table for new reels structure
                CREATE TABLE reels_new (
                    id SERIAL PRIMARY KEY,
                    user_id INTEGER NOT NULL,
                    platform VARCHAR NOT NULL,
                    reel_id VARCHAR NOT NULL,
                    url VARCHAR NOT NULL,
                    thumbnail_url VARCHAR NOT NULL,
                    caption TEXT,
                    author VARCHAR NOT NULL,
                    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    reel_metadata JSONB,
                    is_synced BOOLEAN NOT NULL DEFAULT TRUE,
                    FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
                );

                -- Copy data from old table to new table
                INSERT INTO reels_new (
                    id, user_id, platform, reel_id, url, thumbnail_url,
                    caption, author, created_at, reel_metadata, is_synced
                )
                SELECT 
                    id, user_id, platform, reel_id, url, thumbnail_url,
                    caption, author, created_at, reel_metadata, is_synced
                FROM reels;

                -- Drop old table and rename new table
                DROP TABLE reels CASCADE;
                ALTER TABLE reels_new RENAME TO reels;

                -- Create indexes
                CREATE INDEX IF NOT EXISTS ix_reels_user_id ON reels (user_id);
                CREATE INDEX IF NOT EXISTS ix_reels_reel_id ON reels (reel_id);
            END IF;
        END $$;
    """)


def downgrade():
    # Create temporary table with category_id column
    op.execute("""
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 
                FROM information_schema.columns 
                WHERE table_name='reels' AND column_name='category_id'
            ) THEN
                -- Create temporary table with category_id
                CREATE TABLE reels_new (
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
                );

                -- Copy data and get first category for each reel
                INSERT INTO reels_new (
                    id, user_id, platform, reel_id, url, thumbnail_url,
                    caption, author, created_at, reel_metadata, is_synced,
                    category_id
                )
                SELECT 
                    r.id, r.user_id, r.platform, r.reel_id, r.url, r.thumbnail_url,
                    r.caption, r.author, r.created_at, r.reel_metadata, r.is_synced,
                    (SELECT category_id FROM reel_categories rc WHERE rc.reel_id = r.id LIMIT 1)
                FROM reels r;

                -- Drop old table and rename new table
                DROP TABLE reels CASCADE;
                ALTER TABLE reels_new RENAME TO reels;

                -- Create indexes
                CREATE INDEX IF NOT EXISTS ix_reels_user_id ON reels (user_id);
                CREATE INDEX IF NOT EXISTS ix_reels_reel_id ON reels (reel_id);
                CREATE INDEX IF NOT EXISTS ix_reels_category_id ON reels (category_id);

                -- Drop the association table
                DROP TABLE IF EXISTS reel_categories;
            END IF;
        END $$;
    """) 