-- SQLite schema for WSB thesis data
-- Run once to initialize the database

CREATE TABLE IF NOT EXISTS comments (
    comment_id TEXT PRIMARY KEY,
    body TEXT NOT NULL,
    author TEXT,
    score INTEGER DEFAULT 1,
    created_utc INTEGER NOT NULL,
    date TEXT NOT NULL,           -- YYYY-MM-DD derived from created_utc
    parent_id TEXT,
    permalink TEXT,
    subreddit TEXT DEFAULT 'wallstreetbets'
);

CREATE TABLE IF NOT EXISTS stock_prices (
    symbol TEXT NOT NULL,
    date TEXT NOT NULL,
    open REAL,
    high REAL,
    low REAL,
    close REAL,
    volume INTEGER,
    adjusted REAL,
    daily_return REAL,
    log_return REAL,
    PRIMARY KEY (symbol, date)
);

CREATE TABLE IF NOT EXISTS daily_sentiment (
    date TEXT NOT NULL,
    lexicon TEXT NOT NULL,
    emotion TEXT NOT NULL,
    raw_count INTEGER DEFAULT 0,
    weighted_count REAL DEFAULT 0,
    normalized REAL DEFAULT 0,
    n_comments INTEGER DEFAULT 0,
    n_authors INTEGER DEFAULT 0,
    avg_score REAL DEFAULT 0,
    PRIMARY KEY (date, lexicon, emotion)
);

-- Indexes for fast queries
CREATE INDEX IF NOT EXISTS idx_comments_date ON comments(date);
CREATE INDEX IF NOT EXISTS idx_comments_score ON comments(score);
CREATE INDEX IF NOT EXISTS idx_comments_author ON comments(author);
CREATE INDEX IF NOT EXISTS idx_stock_prices_date ON stock_prices(date);
CREATE INDEX IF NOT EXISTS idx_daily_sentiment_date ON daily_sentiment(date);
CREATE INDEX IF NOT EXISTS idx_daily_sentiment_lexicon ON daily_sentiment(lexicon);
