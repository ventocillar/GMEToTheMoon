#!/usr/bin/env python3
"""
Migrate Existing CSV/Excel Files to SQLite Database
====================================================

This script converts your existing Reddit comment CSV/Excel files
into a SQLite database for more efficient analysis.

Usage:
    python migrate_csv_to_db.py

    Or with custom paths:
    python migrate_csv_to_db.py --csv-dir ./data --db-path my_data.db

Requirements:
    pip install pandas openpyxl
"""

import pandas as pd
import sqlite3
from pathlib import Path
from datetime import datetime
import argparse
import sys

def migrate_csv_to_sqlite(csv_directory=".",
                          db_path="gme_reddit_data.db",
                          file_pattern="comments_*.xlsx",
                          dry_run=False):
    """
    Migrate existing CSV/Excel files to SQLite database

    Args:
        csv_directory: Directory containing CSV/Excel files
        db_path: Path to SQLite database
        file_pattern: Glob pattern for files to import
        dry_run: If True, show what would be imported without importing
    """

    # Check if database exists
    db_exists = Path(db_path).exists()

    if not db_exists:
        print(f"Database {db_path} does not exist.")
        response = input("Create new database? (y/n): ")
        if response.lower() == 'y':
            from setup_database import create_database
            create_database(db_path)
        else:
            print("Migration cancelled.")
            return

    # Find files to migrate
    csv_dir = Path(csv_directory)
    files = list(csv_dir.glob(file_pattern))

    # Also try CSV files if no Excel files found
    if len(files) == 0:
        files = list(csv_dir.glob(file_pattern.replace('.xlsx', '.csv')))

    if len(files) == 0:
        print(f"No files found matching pattern '{file_pattern}' in {csv_directory}")
        print("\nTip: Check your file pattern. Common patterns:")
        print("  - comments_*.xlsx")
        print("  - comments_*.csv")
        print("  - *.xlsx")
        return

    print(f"\n{'='*60}")
    print(f"MIGRATION PLAN")
    print(f"{'='*60}")
    print(f"Source directory: {csv_dir.absolute()}")
    print(f"Target database: {Path(db_path).absolute()}")
    print(f"Files found: {len(files)}")
    print(f"{'='*60}\n")

    if dry_run:
        print("DRY RUN - No data will be imported\n")

    # Preview files
    print("Files to import:")
    for i, file in enumerate(files, 1):
        print(f"  {i}. {file.name}")

    if not dry_run:
        response = input(f"\nProceed with migration? (y/n): ")
        if response.lower() != 'y':
            print("Migration cancelled.")
            return
    else:
        print("\n" + "="*60 + "\n")
        print("DRY RUN - Analyzing files...\n")

    # Connect to database
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # Track statistics
    total_comments = 0
    total_errors = 0
    file_stats = []

    # Process each file
    for file in files:
        print(f"\nProcessing: {file.name}")

        try:
            # Read file
            if file.suffix == '.xlsx':
                df = pd.read_excel(file)
            else:
                df = pd.read_csv(file, encoding='utf-8')

            print(f"  Rows: {len(df)}")
            print(f"  Columns: {list(df.columns)}")

            # Clean and standardize column names
            df.columns = df.columns.str.lower().str.strip()

            # Map columns to database schema
            column_mapping = {
                'body': 'body',
                'text': 'body',
                'comment': 'body',
                'date': 'created_date',
                'created_date': 'created_date',
                'timestamp': 'created_date',
                'score': 'score',
                'upvotes': 'score',
                'author': 'author',
                'username': 'author',
                'id': 'comment_id',
                'comment_id': 'comment_id'
            }

            # Rename columns
            for old_name, new_name in column_mapping.items():
                if old_name in df.columns:
                    df = df.rename(columns={old_name: new_name})

            # Required columns
            if 'body' not in df.columns:
                print(f"  ⚠️  WARNING: No 'body' column found. Skipping file.")
                total_errors += 1
                continue

            if 'created_date' not in df.columns:
                # Try to extract date from filename
                date_from_filename = extract_date_from_filename(file.name)
                if date_from_filename:
                    df['created_date'] = date_from_filename
                    print(f"  ℹ️  Using date from filename: {date_from_filename}")
                else:
                    print(f"  ⚠️  WARNING: No 'created_date' column found. Skipping file.")
                    total_errors += 1
                    continue

            # Generate comment IDs if not present
            if 'comment_id' not in df.columns:
                df['comment_id'] = [
                    f"{file.stem}_{i}" for i in range(len(df))
                ]

            # Add missing columns with defaults
            if 'submission_id' not in df.columns:
                df['submission_id'] = 'unknown'
            if 'score' not in df.columns:
                df['score'] = 0
            if 'author' not in df.columns:
                df['author'] = '[unknown]'

            # Standardize date format
            df['created_date'] = pd.to_datetime(df['created_date']).dt.strftime('%Y-%m-%d')

            # Add metadata
            df['scraped_at'] = datetime.now().isoformat()
            df['scrape_source'] = f'csv_migration:{file.name}'
            df['created_utc'] = 0  # Unknown
            df['edited'] = False
            df['subreddit'] = 'wallstreetbets'
            df['permalink'] = ''

            # Remove deleted/removed comments
            before_filter = len(df)
            df = df[~df['body'].isin(['[deleted]', '[removed]', ''])]
            after_filter = len(df)

            if before_filter != after_filter:
                print(f"  ℹ️  Filtered out {before_filter - after_filter} deleted/removed comments")

            # Select only columns that exist in database
            db_columns = [
                'comment_id', 'submission_id', 'body', 'author', 'score',
                'created_utc', 'created_date', 'edited', 'subreddit',
                'permalink', 'scraped_at', 'scrape_source'
            ]

            df_to_insert = df[db_columns]

            # Insert into database (or just count for dry run)
            if not dry_run:
                # Use INSERT OR IGNORE to skip duplicates
                df_to_insert.to_sql(
                    'comments',
                    conn,
                    if_exists='append',
                    index=False,
                    method='multi'
                )
                conn.commit()
                print(f"  ✓ Imported {len(df_to_insert)} comments")
            else:
                print(f"  [DRY RUN] Would import {len(df_to_insert)} comments")

            total_comments += len(df_to_insert)

            # Store stats
            file_stats.append({
                'file': file.name,
                'rows': len(df_to_insert),
                'date_range': f"{df['created_date'].min()} to {df['created_date'].max()}"
            })

        except Exception as e:
            print(f"  ❌ ERROR: {e}")
            total_errors += 1
            continue

    # Close connection
    conn.close()

    # Print summary
    print(f"\n{'='*60}")
    print("MIGRATION SUMMARY")
    print(f"{'='*60}")
    print(f"Files processed: {len(files)}")
    print(f"Total comments {'imported' if not dry_run else 'to import'}: {total_comments}")
    print(f"Errors: {total_errors}")

    if file_stats:
        print(f"\nFile Details:")
        for stat in file_stats:
            print(f"  {stat['file']}: {stat['rows']} comments ({stat['date_range']})")

    if not dry_run:
        print(f"\nDatabase: {Path(db_path).absolute()}")
        print(f"Size: {Path(db_path).stat().st_size / 1024 / 1024:.2f} MB")
    else:
        print(f"\n{'='*60}")
        print("DRY RUN COMPLETE - No data was imported")
        print("Run without --dry-run to perform actual migration")

    print(f"{'='*60}\n")

    if not dry_run and total_comments > 0:
        print("Next steps:")
        print("1. Validate data: python validate_data.py")
        print("2. Analyze in R: source('analysis_from_db.R')")
        print(f"{'='*60}\n")


def extract_date_from_filename(filename):
    """
    Try to extract date from filename like 'comments_13_Jan.xlsx'
    Returns date string in YYYY-MM-DD format or None
    """
    import re

    # Pattern: comments_DD_Mon.xlsx or comments_DD_Month.xlsx
    pattern = r'comments_(\d+)_([A-Za-z]+)'
    match = re.search(pattern, filename)

    if match:
        day = match.group(1)
        month = match.group(2)

        # Assume year 2021 (you can make this configurable)
        year = "2021"

        # Convert month name to number
        month_map = {
            'jan': '01', 'feb': '02', 'mar': '03', 'apr': '04',
            'may': '05', 'jun': '06', 'jul': '07', 'aug': '08',
            'sep': '09', 'oct': '10', 'nov': '11', 'dec': '12',
            'january': '01', 'february': '02', 'march': '03', 'april': '04',
            'may': '05', 'june': '06', 'july': '07', 'august': '08',
            'september': '09', 'october': '10', 'november': '11', 'december': '12'
        }

        month_num = month_map.get(month.lower())
        if month_num:
            return f"{year}-{month_num}-{day.zfill(2)}"

    return None


def validate_migration(db_path="gme_reddit_data.db"):
    """Validate migrated data"""

    if not Path(db_path).exists():
        print(f"Database {db_path} does not exist.")
        return

    conn = sqlite3.connect(db_path)

    print(f"\n{'='*60}")
    print("VALIDATION REPORT")
    print(f"{'='*60}\n")

    # Count comments
    cursor = conn.cursor()
    cursor.execute("SELECT COUNT(*) FROM comments")
    n_comments = cursor.fetchone()[0]
    print(f"Total comments: {n_comments}")

    # Date range
    cursor.execute("""
        SELECT MIN(created_date), MAX(created_date)
        FROM comments
    """)
    min_date, max_date = cursor.fetchone()
    print(f"Date range: {min_date} to {max_date}")

    # Comments per day
    cursor.execute("""
        SELECT created_date, COUNT(*) as n
        FROM comments
        GROUP BY created_date
        ORDER BY created_date
    """)

    print(f"\nComments per day:")
    for date, count in cursor.fetchall():
        print(f"  {date}: {count}")

    # Check for issues
    cursor.execute("""
        SELECT COUNT(*) FROM comments
        WHERE body IN ('[deleted]', '[removed]')
    """)
    n_deleted = cursor.fetchone()[0]
    print(f"\nDeleted/removed comments: {n_deleted}")

    # Duplicates
    cursor.execute("""
        SELECT comment_id, COUNT(*) as n
        FROM comments
        GROUP BY comment_id
        HAVING n > 1
    """)
    duplicates = cursor.fetchall()
    print(f"Duplicate comment IDs: {len(duplicates)}")

    conn.close()

    print(f"\n{'='*60}\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Migrate CSV/Excel files to SQLite database"
    )

    parser.add_argument(
        '--csv-dir',
        default='.',
        help='Directory containing CSV/Excel files (default: current directory)'
    )

    parser.add_argument(
        '--db-path',
        default='gme_reddit_data.db',
        help='Path to SQLite database (default: gme_reddit_data.db)'
    )

    parser.add_argument(
        '--pattern',
        default='comments_*.xlsx',
        help='File pattern to match (default: comments_*.xlsx)'
    )

    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Show what would be imported without actually importing'
    )

    parser.add_argument(
        '--validate',
        action='store_true',
        help='Validate database after migration'
    )

    args = parser.parse_args()

    # Run migration
    migrate_csv_to_sqlite(
        csv_directory=args.csv_dir,
        db_path=args.db_path,
        file_pattern=args.pattern,
        dry_run=args.dry_run
    )

    # Validate if requested
    if args.validate and not args.dry_run:
        validate_migration(args.db_path)
