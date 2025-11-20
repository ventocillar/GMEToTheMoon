# Reddit Data Collection & Storage Pipeline
## Best Practices for WSB/GME Sentiment Analysis

---

## I. PROBLEM ANALYSIS: Why CSV Files Are Inefficient

### Current Workflow Issues:

```
Python Scraper → Multiple CSV Files (one per day) → R Analysis
                 ↓
                 Problems:
                 - 17+ separate files to manage
                 - Duplicate data across files
                 - Hard to query/filter
                 - Large file sizes (text is verbose)
                 - No data validation
                 - Encoding issues (emojis!)
                 - Version control nightmare
```

### Specific Problems with CSV Approach:

1. **File Management Nightmare**
   - 17 files for 17 days (lines 40-58 in your code)
   - Repetitive loading code (lines 61-110)
   - Hard to add new dates
   - Risk of file corruption

2. **Performance Issues**
   - Loading 17 files sequentially is slow
   - Each CSV is parsed fresh every time
   - R holds everything in memory

3. **Data Integrity**
   - No schema enforcement (columns can change)
   - No data type validation
   - Duplicate comments across files possible
   - No primary keys

4. **Encoding Problems**
   - Emojis may not save/load correctly in CSV
   - Special characters cause issues
   - UTF-8 encoding inconsistencies

5. **Collaboration Issues**
   - CSV files don't merge well in Git
   - Binary diffs make version control hard
   - Can't easily share with collaborators

6. **Scalability**
   - What if you expand to 3 months? 90 files?
   - What if you add other subreddits?
   - Memory constraints with large CSVs

---

## II. RECOMMENDED SOLUTION: SQLite Database

### Why SQLite?

**Perfect for academic research:**
- ✅ Single file (easy to backup/share)
- ✅ No server setup required
- ✅ Works on any platform (Windows/Mac/Linux)
- ✅ SQL queries (powerful filtering)
- ✅ Handles millions of rows
- ✅ Enforces data types and constraints
- ✅ Excellent R and Python support
- ✅ Git-friendly (can store in repo with Git LFS)

**Compared to alternatives:**

| Feature | CSV | SQLite | PostgreSQL | MongoDB |
|---------|-----|--------|------------|---------|
| Setup complexity | Easy | Easy | Medium | Medium |
| Single file | Yes | Yes | No (server) | No (server) |
| Query capability | None | SQL | SQL | NoSQL |
| Performance (small data) | Good | Excellent | Good | Good |
| Performance (large data) | Poor | Good | Excellent | Excellent |
| Portability | Excellent | Excellent | Poor | Poor |
| R integration | Native | Excellent | Good | Fair |
| Python integration | Native | Excellent | Excellent | Excellent |
| Data validation | None | Yes | Yes | Flexible |
| **Best for thesis?** | ❌ | ✅ | ⚠️ Overkill | ⚠️ Overkill |

**Verdict:** Use SQLite for your thesis unless you have >10 million comments.

---

## III. COMPLETE WORKFLOW ARCHITECTURE

### Recommended Pipeline:

```
┌─────────────────────────────────────────────────────────────┐
│ PHASE 1: DATA COLLECTION (Python)                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Reddit API (PRAW/Pushshift)                               │
│         ↓                                                   │
│  Python Scraper (with error handling)                      │
│         ↓                                                   │
│  SQLite Database (gme_reddit_data.db)                      │
│         ↓                                                   │
│  Tables:                                                    │
│    - comments (id, body, date, score, author, etc.)        │
│    - submissions (id, title, score, num_comments, etc.)    │
│    - metadata (scrape_date, source, status)                │
│                                                             │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ PHASE 2: DATA ANALYSIS (R)                                 │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  SQLite Database (read-only)                               │
│         ↓                                                   │
│  R (RSQLite package)                                       │
│         ↓                                                   │
│  SQL Queries (filter, aggregate, join)                     │
│         ↓                                                   │
│  Sentiment Analysis                                         │
│         ↓                                                   │
│  Regression Models                                          │
│         ↓                                                   │
│  Results (figures, tables)                                  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Key Advantages:

1. **Separation of concerns:** Scraping (Python) separate from analysis (R)
2. **Single source of truth:** One database file
3. **Incremental updates:** Add new data without re-scraping everything
4. **Efficient queries:** Load only what you need
5. **Reproducibility:** Same data, consistent results
6. **Version control:** Track database versions with Git LFS

---

## IV. IMPLEMENTATION: Python Scraping to SQLite

### Step 1: Database Schema Design

```python
# setup_database.py

import sqlite3
from datetime import datetime

def create_database(db_path="gme_reddit_data.db"):
    """Create SQLite database with proper schema"""

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # Comments table
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS comments (
        comment_id TEXT PRIMARY KEY,
        submission_id TEXT NOT NULL,
        body TEXT NOT NULL,
        author TEXT,
        score INTEGER,
        created_utc INTEGER NOT NULL,
        created_date TEXT NOT NULL,
        edited BOOLEAN,
        subreddit TEXT,
        permalink TEXT,

        -- Metadata
        scraped_at TEXT NOT NULL,
        scrape_source TEXT,

        -- Indices for fast queries
        FOREIGN KEY (submission_id) REFERENCES submissions(submission_id)
    )
    """)

    # Submissions table
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS submissions (
        submission_id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        selftext TEXT,
        author TEXT,
        score INTEGER,
        upvote_ratio REAL,
        num_comments INTEGER,
        created_utc INTEGER NOT NULL,
        created_date TEXT NOT NULL,
        url TEXT,
        subreddit TEXT,

        -- Metadata
        scraped_at TEXT NOT NULL,
        scrape_source TEXT
    )
    """)

    # Scraping metadata table (track what's been scraped)
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS scrape_metadata (
        scrape_id INTEGER PRIMARY KEY AUTOINCREMENT,
        scrape_date TEXT NOT NULL,
        start_date TEXT,
        end_date TEXT,
        subreddit TEXT,
        n_submissions INTEGER,
        n_comments INTEGER,
        status TEXT,
        error_message TEXT
    )
    """)

    # Create indices for fast queries
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_comments_date ON comments(created_date)")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_comments_score ON comments(score)")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_submissions_date ON submissions(created_date)")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_comments_submission ON comments(submission_id)")

    conn.commit()
    conn.close()

    print(f"Database created successfully: {db_path}")

if __name__ == "__main__":
    create_database()
```

### Step 2: Reddit Scraper with Database Integration

```python
# scrape_reddit_to_db.py

import praw
import sqlite3
from datetime import datetime, timedelta
import time
import logging

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('scraping.log'),
        logging.StreamHandler()
    ]
)

class RedditScraperDB:
    """Scrape Reddit data and store in SQLite database"""

    def __init__(self, db_path="gme_reddit_data.db"):
        self.db_path = db_path
        self.conn = None

        # Initialize Reddit API (you need to set these up)
        self.reddit = praw.Reddit(
            client_id="YOUR_CLIENT_ID",
            client_secret="YOUR_CLIENT_SECRET",
            user_agent="GME Thesis Scraper v1.0"
        )

    def connect(self):
        """Connect to database"""
        self.conn = sqlite3.connect(self.db_path)

    def disconnect(self):
        """Disconnect from database"""
        if self.conn:
            self.conn.close()

    def scrape_submissions(self, subreddit_name, start_date, end_date, keywords=None):
        """
        Scrape submissions from subreddit in date range

        Args:
            subreddit_name: Name of subreddit (e.g., 'wallstreetbets')
            start_date: datetime object
            end_date: datetime object
            keywords: List of keywords to filter (e.g., ['GME', 'GameStop'])
        """
        self.connect()
        cursor = self.conn.cursor()

        # Start scrape metadata
        scrape_id = self._start_scrape_log(subreddit_name, start_date, end_date)

        try:
            subreddit = self.reddit.subreddit(subreddit_name)
            submissions_scraped = 0

            logging.info(f"Scraping {subreddit_name} from {start_date} to {end_date}")

            # Use Pushshift API for historical data (PRAW is limited)
            # Or use PRAW's search with time filters

            # Example: Search for GME-related posts
            search_query = " OR ".join(keywords) if keywords else ""

            for submission in subreddit.search(
                query=search_query,
                sort='new',
                time_filter='all',
                limit=None
            ):
                # Check if in date range
                submission_date = datetime.fromtimestamp(submission.created_utc)

                if submission_date < start_date:
                    break  # Past our window
                if submission_date > end_date:
                    continue  # Not yet in window

                # Check if already exists
                if self._submission_exists(submission.id):
                    logging.debug(f"Submission {submission.id} already exists, skipping")
                    continue

                # Insert submission
                cursor.execute("""
                INSERT OR IGNORE INTO submissions VALUES (
                    ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
                )
                """, (
                    submission.id,
                    submission.title,
                    submission.selftext,
                    str(submission.author),
                    submission.score,
                    submission.upvote_ratio,
                    submission.num_comments,
                    submission.created_utc,
                    submission_date.strftime('%Y-%m-%d'),
                    submission.url,
                    subreddit_name,
                    datetime.now().isoformat(),
                    'praw'
                ))

                submissions_scraped += 1

                if submissions_scraped % 10 == 0:
                    logging.info(f"Scraped {submissions_scraped} submissions...")
                    self.conn.commit()

                # Rate limiting
                time.sleep(0.5)

            self.conn.commit()
            self._complete_scrape_log(scrape_id, submissions_scraped, 0, "success")
            logging.info(f"Scraping complete: {submissions_scraped} submissions")

        except Exception as e:
            logging.error(f"Error during scraping: {e}")
            self._complete_scrape_log(scrape_id, 0, 0, "error", str(e))
            raise

        finally:
            self.disconnect()

    def scrape_comments(self, submission_ids=None, limit=None):
        """
        Scrape comments for submissions

        Args:
            submission_ids: List of submission IDs (if None, scrape all)
            limit: Max comments per submission (None = all)
        """
        self.connect()
        cursor = self.conn.cursor()

        try:
            # Get submissions to scrape
            if submission_ids:
                placeholders = ','.join('?' * len(submission_ids))
                cursor.execute(
                    f"SELECT submission_id FROM submissions WHERE submission_id IN ({placeholders})",
                    submission_ids
                )
            else:
                cursor.execute("SELECT submission_id FROM submissions")

            submissions = cursor.fetchall()
            logging.info(f"Scraping comments for {len(submissions)} submissions")

            comments_scraped = 0

            for (submission_id,) in submissions:
                try:
                    submission = self.reddit.submission(id=submission_id)
                    submission.comments.replace_more(limit=0)  # Remove "load more" comments

                    for comment in submission.comments.list()[:limit]:
                        # Skip if already exists
                        if self._comment_exists(comment.id):
                            continue

                        cursor.execute("""
                        INSERT OR IGNORE INTO comments VALUES (
                            ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
                        )
                        """, (
                            comment.id,
                            submission_id,
                            comment.body,
                            str(comment.author),
                            comment.score,
                            comment.created_utc,
                            datetime.fromtimestamp(comment.created_utc).strftime('%Y-%m-%d'),
                            comment.edited != False,
                            comment.subreddit.display_name,
                            comment.permalink,
                            datetime.now().isoformat(),
                            'praw'
                        ))

                        comments_scraped += 1

                        if comments_scraped % 100 == 0:
                            logging.info(f"Scraped {comments_scraped} comments...")
                            self.conn.commit()

                    time.sleep(1)  # Rate limiting

                except Exception as e:
                    logging.error(f"Error scraping comments for {submission_id}: {e}")
                    continue

            self.conn.commit()
            logging.info(f"Comment scraping complete: {comments_scraped} comments")

        finally:
            self.disconnect()

    def _submission_exists(self, submission_id):
        """Check if submission already in database"""
        cursor = self.conn.cursor()
        cursor.execute("SELECT 1 FROM submissions WHERE submission_id = ?", (submission_id,))
        return cursor.fetchone() is not None

    def _comment_exists(self, comment_id):
        """Check if comment already in database"""
        cursor = self.conn.cursor()
        cursor.execute("SELECT 1 FROM comments WHERE comment_id = ?", (comment_id,))
        return cursor.fetchone() is not None

    def _start_scrape_log(self, subreddit, start_date, end_date):
        """Log scrape start"""
        cursor = self.conn.cursor()
        cursor.execute("""
        INSERT INTO scrape_metadata (scrape_date, start_date, end_date, subreddit, status)
        VALUES (?, ?, ?, ?, 'running')
        """, (
            datetime.now().isoformat(),
            start_date.strftime('%Y-%m-%d'),
            end_date.strftime('%Y-%m-%d'),
            subreddit
        ))
        self.conn.commit()
        return cursor.lastrowid

    def _complete_scrape_log(self, scrape_id, n_submissions, n_comments, status, error_msg=None):
        """Log scrape completion"""
        cursor = self.conn.cursor()
        cursor.execute("""
        UPDATE scrape_metadata
        SET n_submissions = ?, n_comments = ?, status = ?, error_message = ?
        WHERE scrape_id = ?
        """, (n_submissions, n_comments, status, error_msg, scrape_id))
        self.conn.commit()


# Usage example
if __name__ == "__main__":
    # Create database
    from setup_database import create_database
    create_database()

    # Initialize scraper
    scraper = RedditScraperDB("gme_reddit_data.db")

    # Scrape submissions
    start = datetime(2021, 1, 13)
    end = datetime(2021, 1, 31)

    scraper.scrape_submissions(
        subreddit_name='wallstreetbets',
        start_date=start,
        end_date=end,
        keywords=['GME', 'GameStop', 'Gamestop']
    )

    # Scrape comments
    scraper.scrape_comments(limit=1000)  # Top 1000 comments per submission

    print("Scraping complete! Database ready for analysis.")
```

### Step 3: Data Validation Script

```python
# validate_data.py

import sqlite3
import pandas as pd

def validate_database(db_path="gme_reddit_data.db"):
    """Validate database contents"""

    conn = sqlite3.connect(db_path)

    print("=" * 60)
    print("DATABASE VALIDATION REPORT")
    print("=" * 60)

    # Check submissions
    submissions = pd.read_sql("SELECT COUNT(*) as n FROM submissions", conn)
    print(f"\nSubmissions: {submissions['n'][0]}")

    # Check comments
    comments = pd.read_sql("SELECT COUNT(*) as n FROM comments", conn)
    print(f"Comments: {comments['n'][0]}")

    # Date range
    date_range = pd.read_sql("""
    SELECT
        MIN(created_date) as min_date,
        MAX(created_date) as max_date
    FROM comments
    """, conn)
    print(f"\nDate range: {date_range['min_date'][0]} to {date_range['max_date'][0]}")

    # Comments per day
    daily_counts = pd.read_sql("""
    SELECT
        created_date,
        COUNT(*) as n_comments,
        AVG(score) as avg_score
    FROM comments
    GROUP BY created_date
    ORDER BY created_date
    """, conn)
    print(f"\nComments per day:")
    print(daily_counts)

    # Check for duplicates
    duplicates = pd.read_sql("""
    SELECT comment_id, COUNT(*) as n
    FROM comments
    GROUP BY comment_id
    HAVING n > 1
    """, conn)
    print(f"\nDuplicate comments: {len(duplicates)}")

    # Check for deleted/removed
    deleted = pd.read_sql("""
    SELECT COUNT(*) as n
    FROM comments
    WHERE body IN ('[deleted]', '[removed]')
    """, conn)
    print(f"Deleted/removed comments: {deleted['n'][0]}")

    # Score distribution
    score_dist = pd.read_sql("""
    SELECT
        MIN(score) as min_score,
        AVG(score) as avg_score,
        MAX(score) as max_score,
        COUNT(CASE WHEN score > 100 THEN 1 END) as high_score_count
    FROM comments
    """, conn)
    print(f"\nScore distribution:")
    print(score_dist)

    # Check emojis
    emoji_check = pd.read_sql("""
    SELECT COUNT(*) as n
    FROM comments
    WHERE body LIKE '%🚀%' OR body LIKE '%💎%'
    """, conn)
    print(f"\nComments with 🚀 or 💎: {emoji_check['n'][0]}")

    conn.close()

    print("\n" + "=" * 60)
    print("Validation complete!")
    print("=" * 60)

if __name__ == "__main__":
    validate_database()
```

---

## V. IMPLEMENTATION: R Analysis from SQLite

### Step 1: Connect to Database in R

```r
# load_data_from_db.R

library(DBI)
library(RSQLite)
library(tidyverse)
library(lubridate)

# Connect to database
conn <- dbConnect(RSQLite::SQLite(), "gme_reddit_data.db")

# List tables
dbListTables(conn)

# Check what's in comments table
dbListFields(conn, "comments")

# Get summary
dbGetQuery(conn, "
  SELECT
    COUNT(*) as n_comments,
    MIN(created_date) as start_date,
    MAX(created_date) as end_date
  FROM comments
")
```

### Step 2: Query Data Efficiently

```r
# ===== APPROACH 1: Load All Data =====
# Simple but memory-intensive

all_comments <- dbGetQuery(conn, "
  SELECT
    comment_id,
    body,
    created_date as date,
    score,
    author
  FROM comments
  WHERE body NOT IN ('[deleted]', '[removed]')
  ORDER BY created_date
")

# Convert to tibble
all_comments <- as_tibble(all_comments) %>%
  mutate(date = as.Date(date))


# ===== APPROACH 2: Filter in SQL (RECOMMENDED) =====
# Much more efficient!

# Only load comments from January 2021 with score > 5
filtered_comments <- dbGetQuery(conn, "
  SELECT
    comment_id,
    body,
    created_date as date,
    score
  FROM comments
  WHERE
    created_date BETWEEN '2021-01-13' AND '2021-01-31'
    AND score >= 5
    AND body NOT IN ('[deleted]', '[removed]')
    AND LENGTH(body) > 10
  ORDER BY created_date, score DESC
")


# ===== APPROACH 3: Aggregate in SQL (BEST FOR LARGE DATA) =====
# Pre-aggregate before loading into R

daily_stats <- dbGetQuery(conn, "
  SELECT
    created_date as date,
    COUNT(*) as n_comments,
    AVG(score) as avg_score,
    SUM(CASE WHEN score > 100 THEN 1 ELSE 0 END) as high_score_count,
    SUM(CASE WHEN body LIKE '%🚀%' THEN 1 ELSE 0 END) as rocket_emoji_count
  FROM comments
  WHERE
    created_date BETWEEN '2021-01-01' AND '2021-02-28'
    AND body NOT IN ('[deleted]', '[removed]')
  GROUP BY created_date
  ORDER BY created_date
")


# ===== APPROACH 4: Sampling =====
# For testing/development, use a sample

sample_comments <- dbGetQuery(conn, "
  SELECT *
  FROM comments
  WHERE created_date = '2021-01-27'
  ORDER BY RANDOM()
  LIMIT 1000
")
```

### Step 3: Complete Analysis Script

```r
# analysis_from_db.R

library(DBI)
library(RSQLite)
library(tidyverse)
library(tidytext)
library(tidyquant)

# ===== CONNECT =====
conn <- dbConnect(RSQLite::SQLite(), "gme_reddit_data.db")

cat("Connected to database\n")

# ===== LOAD DATA =====
cat("Loading comments from database...\n")

comments <- dbGetQuery(conn, "
  SELECT
    comment_id,
    body,
    created_date as date,
    score,
    author
  FROM comments
  WHERE
    created_date BETWEEN '2021-01-13' AND '2021-01-31'
    AND body NOT IN ('[deleted]', '[removed]')
    AND LENGTH(body) > 10
")

comments <- as_tibble(comments) %>%
  mutate(date = as.Date(date))

cat(sprintf("Loaded %d comments\n", nrow(comments)))

# Close connection (we're done with database)
dbDisconnect(conn)

# ===== NOW YOUR EXISTING ANALYSIS =====
# Everything from here is the same as your current code!

# Tokenize
tokens <- comments %>%
  unnest_tokens(word, body)

# Remove stop words
data(stop_words)
tokens <- tokens %>%
  anti_join(stop_words)

# Calculate sentiment
bing <- get_sentiments("bing")

sentiment <- tokens %>%
  inner_join(bing) %>%
  mutate(sentiment_value = ifelse(sentiment == "positive", 1, -1)) %>%
  group_by(date) %>%
  summarize(
    daily_sentiment = sum(sentiment_value),
    n_words = n()
  )

# Get stock data
gme <- tq_get("GME", from = "2021-01-13", to = "2021-01-31") %>%
  mutate(return = (adjusted - lag(adjusted)) / lag(adjusted) * 100)

# Merge
analysis_data <- gme %>%
  left_join(sentiment, by = "date")

# Regression
model <- lm(return ~ lag(daily_sentiment, 1), data = analysis_data)
summary(model)
```

### Step 4: Database Query Helper Functions

```r
# db_helpers.R
# Reusable functions for database operations

library(DBI)
library(RSQLite)
library(tidyverse)

#' Connect to GME database
#' @param db_path Path to database file
#' @return Database connection
connect_db <- function(db_path = "gme_reddit_data.db") {
  conn <- dbConnect(RSQLite::SQLite(), db_path)
  return(conn)
}

#' Load comments with filters
#' @param start_date Start date (character or Date)
#' @param end_date End date
#' @param min_score Minimum score
#' @param sample_size Sample size (NULL = all)
#' @return Tibble of comments
load_comments <- function(start_date = "2021-01-13",
                         end_date = "2021-01-31",
                         min_score = 0,
                         sample_size = NULL) {

  conn <- connect_db()

  # Build query
  query <- sprintf("
    SELECT
      comment_id,
      body,
      created_date as date,
      score,
      author
    FROM comments
    WHERE
      created_date BETWEEN '%s' AND '%s'
      AND score >= %d
      AND body NOT IN ('[deleted]', '[removed]')
      AND LENGTH(body) > 10
    ORDER BY created_date, score DESC
  ", start_date, end_date, min_score)

  # Add sampling if requested
  if (!is.null(sample_size)) {
    query <- paste(query, sprintf("LIMIT %d", sample_size))
  }

  # Execute query
  comments <- dbGetQuery(conn, query)
  dbDisconnect(conn)

  # Convert to tibble
  comments <- as_tibble(comments) %>%
    mutate(date = as.Date(date))

  return(comments)
}

#' Get daily aggregates
#' @return Tibble with daily comment statistics
get_daily_stats <- function(start_date = "2021-01-13",
                           end_date = "2021-01-31") {

  conn <- connect_db()

  stats <- dbGetQuery(conn, sprintf("
    SELECT
      created_date as date,
      COUNT(*) as n_comments,
      AVG(score) as avg_score,
      MAX(score) as max_score,
      SUM(CASE WHEN score > 100 THEN 1 ELSE 0 END) as high_score_count
    FROM comments
    WHERE created_date BETWEEN '%s' AND '%s'
    GROUP BY created_date
    ORDER BY created_date
  ", start_date, end_date))

  dbDisconnect(conn)

  stats <- as_tibble(stats) %>%
    mutate(date = as.Date(date))

  return(stats)
}

#' Search comments by keyword
#' @param keywords Vector of keywords
#' @return Matching comments
search_comments <- function(keywords, start_date = "2021-01-01") {

  conn <- connect_db()

  # Build LIKE conditions
  conditions <- paste(
    sprintf("body LIKE '%%%s%%'", keywords),
    collapse = " OR "
  )

  query <- sprintf("
    SELECT *
    FROM comments
    WHERE (%s) AND created_date >= '%s'
  ", conditions, start_date)

  results <- dbGetQuery(conn, query)
  dbDisconnect(conn)

  return(as_tibble(results))
}

# Example usage:
# comments <- load_comments(start_date = "2021-01-13", end_date = "2021-01-31", min_score = 5)
# daily_stats <- get_daily_stats()
# gme_mentions <- search_comments(c("GME", "GameStop"))
```

---

## VI. ADVANTAGES OF DATABASE APPROACH

### Before (CSV):

```r
# Load 17 files
my_gamestop_13jan <- read_excel("comments_13_Jan.xlsx")
my_gamestop_14jan <- read_excel("comments_14_Jan.xlsx")
# ... repeat 15 more times

# Combine
my_gamestop <- bind_rows(...)

# Filter
my_gamestop_filtered <- my_gamestop %>%
  filter(score > 5, !body %in% c("[deleted]", "[removed]"))
```

**Problems:**
- 17 separate file reads
- All data loaded into memory
- No incremental updates
- Filtering happens in R (slow)

### After (SQLite):

```r
# One query, filtered at source
comments <- dbGetQuery(conn, "
  SELECT * FROM comments
  WHERE
    created_date BETWEEN '2021-01-13' AND '2021-01-31'
    AND score > 5
    AND body NOT IN ('[deleted]', '[removed]')
")
```

**Benefits:**
- One file, one query
- Only filtered data loaded
- Fast (indexed queries)
- Easy to add new data
- Reproducible

---

## VII. MIGRATION GUIDE: CSV → SQLite

### Convert Your Existing CSV Files

```python
# migrate_csv_to_db.py

import pandas as pd
import sqlite3
from pathlib import Path
from datetime import datetime

def migrate_csv_to_sqlite(csv_directory, db_path="gme_reddit_data.db"):
    """Migrate existing CSV files to SQLite"""

    # Create database
    from setup_database import create_database
    create_database(db_path)

    # Connect
    conn = sqlite3.connect(db_path)

    # Find all CSV files
    csv_files = list(Path(csv_directory).glob("comments_*.xlsx"))
    # Or: csv_files = list(Path(csv_directory).glob("comments_*.csv"))

    print(f"Found {len(csv_files)} files to migrate")

    total_comments = 0

    for csv_file in csv_files:
        print(f"Migrating {csv_file.name}...")

        # Read CSV/Excel
        if csv_file.suffix == '.xlsx':
            df = pd.read_excel(csv_file)
        else:
            df = pd.read_csv(csv_file)

        # Clean column names
        df = df.rename(columns={
            'body': 'body',
            'date': 'created_date',
            'score': 'score',
            'author': 'author'
        })

        # Add required columns
        df['comment_id'] = df.index  # Generate IDs if not present
        df['submission_id'] = 'unknown'  # If not present
        df['created_utc'] = pd.to_datetime(df['created_date']).astype(int) // 10**9
        df['edited'] = False
        df['subreddit'] = 'wallstreetbets'
        df['permalink'] = ''
        df['scraped_at'] = datetime.now().isoformat()
        df['scrape_source'] = 'csv_migration'

        # Insert into database
        df.to_sql('comments', conn, if_exists='append', index=False)

        total_comments += len(df)
        print(f"  Migrated {len(df)} comments")

    conn.commit()
    conn.close()

    print(f"\nMigration complete: {total_comments} total comments")
    print(f"Database: {db_path}")

if __name__ == "__main__":
    # Adjust to your CSV directory
    migrate_csv_to_sqlite(csv_directory="./data")
```

---

## VIII. BEST PRACTICES

### 1. **Separation of Concerns**

```
┌──────────────────┐
│ scrape_reddit.py │  ← Data collection (run once or periodically)
└──────────────────┘
         ↓
┌──────────────────┐
│ gme_data.db      │  ← Single source of truth
└──────────────────┘
         ↓
┌──────────────────┐
│ analysis.R       │  ← Analysis (run multiple times)
└──────────────────┘
```

### 2. **Version Control**

```bash
# .gitignore
*.xlsx
*.csv
gme_reddit_data.db  # Too large for Git

# But DO commit:
setup_database.py
scrape_reddit_to_db.py
analysis_from_db.R

# Use Git LFS for database if needed
git lfs track "*.db"
```

### 3. **Incremental Updates**

```python
# Update database with new data
def update_database():
    """Add new comments without re-scraping everything"""

    conn = sqlite3.connect("gme_reddit_data.db")

    # Get most recent date in database
    cursor = conn.cursor()
    cursor.execute("SELECT MAX(created_date) FROM comments")
    last_date = cursor.fetchone()[0]

    print(f"Last data: {last_date}")
    print("Scraping new data...")

    # Scrape from last_date + 1 to today
    scraper = RedditScraperDB()
    scraper.scrape_submissions(
        subreddit_name='wallstreetbets',
        start_date=datetime.fromisoformat(last_date) + timedelta(days=1),
        end_date=datetime.now(),
        keywords=['GME']
    )

    conn.close()
```

### 4. **Backup Strategy**

```bash
# Backup database regularly
cp gme_reddit_data.db backups/gme_reddit_data_$(date +%Y%m%d).db

# Or use SQLite backup command
sqlite3 gme_reddit_data.db ".backup backups/backup_$(date +%Y%m%d).db"
```

### 5. **Testing**

```r
# Test on small sample before full analysis
test_comments <- load_comments(
  start_date = "2021-01-27",
  end_date = "2021-01-27",
  sample_size = 100
)

# Run your analysis pipeline on test data
# Verify it works, then scale up
```

---

## IX. WHEN TO USE WHAT

| Use Case | Recommended Solution |
|----------|---------------------|
| Thesis with <100K comments | **SQLite** ✅ |
| Thesis with >100K comments | SQLite or PostgreSQL |
| Thesis with >1M comments | PostgreSQL |
| Quick one-off analysis | CSV (acceptable) |
| Reproducible research | **SQLite** ✅ |
| Collaboration (multiple people) | SQLite with Git LFS or PostgreSQL |
| Real-time data pipeline | PostgreSQL or MongoDB |
| Multiple subreddits/stocks | **SQLite** ✅ (with good schema) |

---

## X. COMPLETE EXAMPLE: YOUR WORKFLOW

### Setup (One Time):

```bash
# 1. Create project structure
mkdir -p gme_project/{data,scripts,output}
cd gme_project

# 2. Setup database
python scripts/setup_database.py

# 3. Scrape data
python scripts/scrape_reddit_to_db.py

# 4. Validate
python scripts/validate_data.py
```

### Analysis (Repeatable):

```r
# analysis.R

# Connect to database
source("scripts/db_helpers.R")

# Load data
comments <- load_comments(
  start_date = "2021-01-13",
  end_date = "2021-01-31",
  min_score = 5
)

# Your sentiment analysis
sentiment <- calculate_sentiment(comments)

# Merge with stock data
analysis_data <- merge_with_stocks(sentiment)

# Run models
results <- run_regression(analysis_data)

# Generate outputs
create_plots(results)
create_tables(results)
```

### Update (When Needed):

```python
# update.py

from scrape_reddit_to_db import RedditScraperDB

scraper = RedditScraperDB()
scraper.scrape_submissions(
    subreddit_name='wallstreetbets',
    start_date=datetime(2021, 2, 1),
    end_date=datetime(2021, 2, 28),
    keywords=['GME']
)
```

---

## XI. SUMMARY & RECOMMENDATIONS

### For Your Thesis: **Use SQLite**

**Why:**
1. ✅ Single file (easy to manage)
2. ✅ No server setup
3. ✅ SQL queries (powerful filtering)
4. ✅ Excellent R support (RSQLite)
5. ✅ Handles 1M+ comments easily
6. ✅ Reproducible research
7. ✅ Professional data management

**Implementation Steps:**

1. **Week 1:** Setup database schema (`setup_database.py`)
2. **Week 2:** Migrate existing CSV data (`migrate_csv_to_db.py`)
3. **Week 2:** Update scraping script to write to database
4. **Week 3:** Create R helper functions (`db_helpers.R`)
5. **Week 3:** Update analysis script to read from database
6. **Week 4:** Test end-to-end workflow
7. **Week 4:** Document in thesis methodology

**Time Investment:**
- Initial setup: 4-6 hours
- Migration: 2-3 hours
- Learning curve: 4-5 hours
- **Total: ~15 hours**

**Payoff:**
- Cleaner code
- Faster analysis
- Easier to update data
- Professional approach
- Reproducible research

### Alternative: Improve CSV Approach

If you really don't want to use SQLite, at least:

1. **Use one combined CSV file** instead of 17
2. **Compress with .csv.gz** (automatic with `write_csv(gzip = TRUE)`)
3. **Use `data.table::fread()`** for faster loading
4. **Filter before loading** (if possible)

But honestly, **SQLite is better** for anything beyond quick prototypes.

---

## XII. RESOURCES

### Python Packages:
```bash
pip install praw sqlite3 pandas
```

### R Packages:
```r
install.packages(c("DBI", "RSQLite", "tidyverse"))
```

### Learning Resources:
- SQLite tutorial: https://www.sqlitetutorial.net/
- RSQLite documentation: https://rsqlite.r-dbi.org/
- PRAW docs: https://praw.readthedocs.io/

### Example Repos:
- SQL databases for research: https://github.com/rsquaredacademy/databases
- Reddit scrapers: https://github.com/topics/reddit-scraper

---

**Bottom Line:** For a serious thesis, use SQLite. It's not much harder than CSV, but it's WAY better for data management, analysis, and reproducibility. Your future self (and thesis committee) will thank you! 🎓📊
