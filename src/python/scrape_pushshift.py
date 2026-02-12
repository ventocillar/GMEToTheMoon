#!/usr/bin/env python3
"""
Scrape r/wallstreetbets comments from Arctic Shift API and store in SQLite.

Arctic Shift is a community-maintained Pushshift mirror providing historical
Reddit data. API docs: https://arctic-shift.photon-reddit.com/api/docs

Usage:
    python scrape_pushshift.py [--start 2020-12-01] [--end 2021-03-31] [--db data/wsb_data.sqlite]
"""

import argparse
import json
import logging
import os
import sqlite3
import sys
import time
from datetime import datetime, timezone

import requests

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)
logger = logging.getLogger(__name__)

API_BASE = "https://arctic-shift.photon-reddit.com/api/comments/search"
BATCH_SIZE = 100  # API max per request
RATE_LIMIT_SLEEP = 1.0  # seconds between requests


def init_db(db_path: str) -> sqlite3.Connection:
    """Initialize SQLite database with schema."""
    schema_path = os.path.join(os.path.dirname(__file__), "db_schema.sql")
    conn = sqlite3.connect(db_path)
    with open(schema_path, "r") as f:
        conn.executescript(f.read())
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA synchronous=NORMAL")
    conn.commit()
    return conn


def date_to_epoch(date_str: str) -> int:
    """Convert YYYY-MM-DD to Unix timestamp."""
    dt = datetime.strptime(date_str, "%Y-%m-%d").replace(tzinfo=timezone.utc)
    return int(dt.timestamp())


def epoch_to_date(epoch: int) -> str:
    """Convert Unix timestamp to YYYY-MM-DD."""
    return datetime.fromtimestamp(epoch, tz=timezone.utc).strftime("%Y-%m-%d")


def fetch_comments(after: int, before: int, session: requests.Session) -> list:
    """Fetch a batch of comments from Arctic Shift API."""
    params = {
        "subreddit": "wallstreetbets",
        "after": after,
        "before": before,
        "limit": BATCH_SIZE,
        "sort": "asc",
        "sort_type": "created_utc",
    }
    retries = 0
    max_retries = 5
    while retries < max_retries:
        try:
            resp = session.get(API_BASE, params=params, timeout=30)
            if resp.status_code == 429:
                wait = min(2 ** retries * 5, 60)
                logger.warning(f"Rate limited. Waiting {wait}s...")
                time.sleep(wait)
                retries += 1
                continue
            resp.raise_for_status()
            data = resp.json()
            return data.get("data", [])
        except requests.exceptions.RequestException as e:
            retries += 1
            wait = min(2 ** retries * 2, 30)
            logger.warning(f"Request error: {e}. Retry {retries}/{max_retries} in {wait}s")
            time.sleep(wait)
    logger.error("Max retries exceeded for batch")
    return []


def insert_comments(conn: sqlite3.Connection, comments: list) -> int:
    """Insert comments into SQLite, skipping duplicates. Returns count inserted."""
    inserted = 0
    for c in comments:
        body = c.get("body", "")
        # Skip deleted/removed
        if body in ("[deleted]", "[removed]", ""):
            continue
        try:
            conn.execute(
                """INSERT OR IGNORE INTO comments
                   (comment_id, body, author, score, created_utc, date, parent_id, permalink, subreddit)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                (
                    c.get("id", ""),
                    body,
                    c.get("author", "[deleted]"),
                    c.get("score", 1),
                    c.get("created_utc", 0),
                    epoch_to_date(c.get("created_utc", 0)),
                    c.get("parent_id", ""),
                    c.get("permalink", ""),
                    c.get("subreddit", "wallstreetbets"),
                ),
            )
            inserted += 1
        except sqlite3.IntegrityError:
            pass
    return inserted


def scrape(start_date: str, end_date: str, db_path: str):
    """Main scraping loop."""
    os.makedirs(os.path.dirname(db_path) or ".", exist_ok=True)
    conn = init_db(db_path)
    session = requests.Session()
    session.headers.update({"User-Agent": "GMEToTheMoon-thesis/1.0 (academic research)"})

    start_epoch = date_to_epoch(start_date)
    end_epoch = date_to_epoch(end_date)

    # Check for resume point
    cursor = conn.execute("SELECT MAX(created_utc) FROM comments")
    max_utc = cursor.fetchone()[0]
    if max_utc and max_utc > start_epoch:
        logger.info(f"Resuming from {epoch_to_date(max_utc)} (epoch {max_utc})")
        current_after = max_utc
    else:
        current_after = start_epoch

    total_inserted = 0
    total_fetched = 0
    batch_num = 0

    # Get existing count
    existing = conn.execute("SELECT COUNT(*) FROM comments").fetchone()[0]
    logger.info(f"Existing comments in DB: {existing:,}")
    logger.info(f"Scraping r/wallstreetbets from {start_date} to {end_date}")
    logger.info(f"API: {API_BASE}")

    while current_after < end_epoch:
        batch_num += 1
        comments = fetch_comments(current_after, end_epoch, session)

        if not comments:
            logger.info("No more comments returned. Done.")
            break

        total_fetched += len(comments)
        inserted = insert_comments(conn, comments)
        total_inserted += inserted

        # Move cursor forward
        last_utc = max(c.get("created_utc", 0) for c in comments)
        if last_utc <= current_after:
            # Prevent infinite loop: advance by 1 second
            current_after += 1
        else:
            current_after = last_utc

        current_date = epoch_to_date(current_after)

        if batch_num % 10 == 0:
            conn.commit()
            logger.info(
                f"Batch {batch_num}: fetched={total_fetched:,}, "
                f"inserted={total_inserted:,}, current_date={current_date}"
            )

        time.sleep(RATE_LIMIT_SLEEP)

    conn.commit()

    # Final stats
    total_db = conn.execute("SELECT COUNT(*) FROM comments").fetchone()[0]
    min_date = conn.execute("SELECT MIN(date) FROM comments").fetchone()[0]
    max_date = conn.execute("SELECT MAX(date) FROM comments").fetchone()[0]

    logger.info("=" * 60)
    logger.info("Scraping complete!")
    logger.info(f"Total comments in database: {total_db:,}")
    logger.info(f"Date range: {min_date} to {max_date}")
    logger.info(f"New comments inserted this run: {total_inserted:,}")
    logger.info("=" * 60)

    conn.close()


def main():
    parser = argparse.ArgumentParser(description="Scrape WSB comments from Arctic Shift")
    parser.add_argument("--start", default="2020-12-01", help="Start date (YYYY-MM-DD)")
    parser.add_argument("--end", default="2021-03-31", help="End date (YYYY-MM-DD)")
    parser.add_argument(
        "--db",
        default=os.path.join(
            os.path.dirname(os.path.dirname(os.path.dirname(__file__))),
            "data",
            "wsb_data.sqlite",
        ),
        help="Path to SQLite database",
    )
    args = parser.parse_args()
    scrape(args.start, args.end, args.db)


if __name__ == "__main__":
    main()
