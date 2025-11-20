#!/usr/bin/env python3
"""
Setup SQLite Database for GME Reddit Data
==========================================

This script creates a SQLite database with proper schema for storing
Reddit comments and submissions from r/WallStreetBets.

Usage:
    python setup_database.py

Output:
    gme_reddit_data.db (SQLite database file)
"""

import sqlite3
from datetime import datetime
import os

def create_database(db_path="gme_reddit_data.db"):
    """Create SQLite database with proper schema"""

    # Check if database already exists
    if os.path.exists(db_path):
        response = input(f"Database {db_path} already exists. Overwrite? (y/n): ")
        if response.lower() != 'y':
            print("Operation cancelled.")
            return

    print(f"Creating database: {db_path}")
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # =========================================================================
    # COMMENTS TABLE
    # =========================================================================
    print("Creating comments table...")
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS comments (
        comment_id TEXT PRIMARY KEY,
        submission_id TEXT,
        body TEXT NOT NULL,
        author TEXT,
        score INTEGER DEFAULT 0,
        created_utc INTEGER,
        created_date TEXT NOT NULL,
        edited BOOLEAN DEFAULT 0,
        subreddit TEXT,
        permalink TEXT,

        -- Metadata
        scraped_at TEXT NOT NULL,
        scrape_source TEXT DEFAULT 'manual'
    )
    """)

    # =========================================================================
    # SUBMISSIONS TABLE
    # =========================================================================
    print("Creating submissions table...")
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS submissions (
        submission_id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        selftext TEXT,
        author TEXT,
        score INTEGER DEFAULT 0,
        upvote_ratio REAL,
        num_comments INTEGER,
        created_utc INTEGER,
        created_date TEXT NOT NULL,
        url TEXT,
        subreddit TEXT,

        -- Metadata
        scraped_at TEXT NOT NULL,
        scrape_source TEXT DEFAULT 'manual'
    )
    """)

    # =========================================================================
    # SCRAPING METADATA TABLE
    # =========================================================================
    print("Creating scrape_metadata table...")
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS scrape_metadata (
        scrape_id INTEGER PRIMARY KEY AUTOINCREMENT,
        scrape_date TEXT NOT NULL,
        start_date TEXT,
        end_date TEXT,
        subreddit TEXT,
        n_submissions INTEGER DEFAULT 0,
        n_comments INTEGER DEFAULT 0,
        status TEXT,
        error_message TEXT,
        notes TEXT
    )
    """)

    # =========================================================================
    # INDICES FOR FAST QUERIES
    # =========================================================================
    print("Creating indices...")

    cursor.execute("""
    CREATE INDEX IF NOT EXISTS idx_comments_date
    ON comments(created_date)
    """)

    cursor.execute("""
    CREATE INDEX IF NOT EXISTS idx_comments_score
    ON comments(score)
    """)

    cursor.execute("""
    CREATE INDEX IF NOT EXISTS idx_comments_submission
    ON comments(submission_id)
    """)

    cursor.execute("""
    CREATE INDEX IF NOT EXISTS idx_submissions_date
    ON submissions(created_date)
    """)

    cursor.execute("""
    CREATE INDEX IF NOT EXISTS idx_submissions_score
    ON submissions(score)
    """)

    # =========================================================================
    # VIEWS FOR COMMON QUERIES
    # =========================================================================
    print("Creating views...")

    cursor.execute("""
    CREATE VIEW IF NOT EXISTS comments_with_metadata AS
    SELECT
        c.*,
        s.title as submission_title,
        s.score as submission_score,
        s.num_comments as submission_num_comments
    FROM comments c
    LEFT JOIN submissions s ON c.submission_id = s.submission_id
    """)

    cursor.execute("""
    CREATE VIEW IF NOT EXISTS daily_comment_stats AS
    SELECT
        created_date,
        COUNT(*) as n_comments,
        AVG(score) as avg_score,
        MAX(score) as max_score,
        MIN(score) as min_score,
        SUM(CASE WHEN score > 100 THEN 1 ELSE 0 END) as high_score_count,
        SUM(CASE WHEN LENGTH(body) > 500 THEN 1 ELSE 0 END) as long_comment_count
    FROM comments
    WHERE body NOT IN ('[deleted]', '[removed]')
    GROUP BY created_date
    ORDER BY created_date
    """)

    conn.commit()
    conn.close()

    print(f"\n{'='*60}")
    print("DATABASE CREATED SUCCESSFULLY")
    print(f"{'='*60}")
    print(f"Location: {os.path.abspath(db_path)}")
    print(f"Size: {os.path.getsize(db_path)} bytes")
    print("\nTables created:")
    print("  - comments")
    print("  - submissions")
    print("  - scrape_metadata")
    print("\nIndices created:")
    print("  - idx_comments_date")
    print("  - idx_comments_score")
    print("  - idx_comments_submission")
    print("  - idx_submissions_date")
    print("  - idx_submissions_score")
    print("\nViews created:")
    print("  - comments_with_metadata")
    print("  - daily_comment_stats")
    print(f"\n{'='*60}")
    print("Next steps:")
    print("1. Run migrate_csv_to_db.py to import existing CSV/Excel files")
    print("2. Or run scrape_reddit_to_db.py to scrape new data")
    print("3. Use analysis_from_db.R to analyze data in R")
    print(f"{'='*60}\n")


def show_schema(db_path="gme_reddit_data.db"):
    """Display database schema"""

    if not os.path.exists(db_path):
        print(f"Database {db_path} does not exist. Run create_database() first.")
        return

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # Get all tables
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
    tables = cursor.fetchall()

    print(f"\n{'='*60}")
    print("DATABASE SCHEMA")
    print(f"{'='*60}\n")

    for (table_name,) in tables:
        print(f"Table: {table_name}")
        print("-" * 60)

        cursor.execute(f"PRAGMA table_info({table_name})")
        columns = cursor.fetchall()

        for col in columns:
            col_id, col_name, col_type, not_null, default, pk = col
            pk_str = " PRIMARY KEY" if pk else ""
            null_str = " NOT NULL" if not_null else ""
            print(f"  {col_name:<20} {col_type:<15}{pk_str}{null_str}")

        print()

    conn.close()


if __name__ == "__main__":
    import sys

    # Parse command line arguments
    if len(sys.argv) > 1:
        if sys.argv[1] == "--schema":
            show_schema()
        elif sys.argv[1] == "--help":
            print(__doc__)
        else:
            db_path = sys.argv[1]
            create_database(db_path)
    else:
        create_database()
