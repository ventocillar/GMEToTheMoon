# ============================================================================
# DATABASE HELPER FUNCTIONS FOR R
# ============================================================================
# This script provides convenient functions for loading Reddit data from
# SQLite database into R for analysis.
#
# Usage:
#   source("db_helpers.R")
#   comments <- load_comments(start_date = "2021-01-13", end_date = "2021-01-31")
#   daily_stats <- get_daily_stats()
# ============================================================================

library(DBI)
library(RSQLite)
library(tidyverse)
library(lubridate)

# CONFIGURATION ---------------------------------------------------------------

DB_PATH <- "gme_reddit_data.db"  # Change if your database has a different name

# HELPER FUNCTIONS ------------------------------------------------------------

#' Connect to GME database
#'
#' @param db_path Path to SQLite database file
#' @return Database connection object
#' @export
#'
#' @examples
#' conn <- connect_db()
#' dbListTables(conn)
#' dbDisconnect(conn)
connect_db <- function(db_path = DB_PATH) {

  if (!file.exists(db_path)) {
    stop(sprintf("Database not found: %s\n
Please run setup_database.py first or check the path.", db_path))
  }

  conn <- dbConnect(RSQLite::SQLite(), db_path)
  return(conn)
}


#' Load comments with filters
#'
#' This is the main function you'll use to load Reddit comments for analysis.
#' It loads data directly from the SQLite database with optional filtering.
#'
#' @param start_date Start date (character "YYYY-MM-DD" or Date object)
#' @param end_date End date
#' @param min_score Minimum comment score (upvotes)
#' @param max_score Maximum comment score (NULL = no limit)
#' @param sample_size Number of comments to randomly sample (NULL = all)
#' @param keywords Vector of keywords to filter by (searches in comment body)
#' @param remove_deleted Remove [deleted] and [removed] comments (default: TRUE)
#' @param db_path Path to database
#'
#' @return Tibble with comment data
#' @export
#'
#' @examples
#' # Load all comments from January 2021
#' comments <- load_comments("2021-01-13", "2021-01-31")
#'
#' # Load only high-score comments
#' popular_comments <- load_comments("2021-01-13", "2021-01-31", min_score = 100)
#'
#' # Load sample for testing
#' test_sample <- load_comments("2021-01-13", "2021-01-31", sample_size = 1000)
#'
#' # Load comments mentioning specific keywords
#' gme_comments <- load_comments("2021-01-13", "2021-01-31", keywords = c("GME", "GameStop"))
load_comments <- function(start_date = "2021-01-13",
                         end_date = "2021-01-31",
                         min_score = 0,
                         max_score = NULL,
                         sample_size = NULL,
                         keywords = NULL,
                         remove_deleted = TRUE,
                         db_path = DB_PATH) {

  conn <- connect_db(db_path)

  # Build WHERE clauses
  where_clauses <- c()

  # Date filter
  where_clauses <- c(
    where_clauses,
    sprintf("created_date BETWEEN '%s' AND '%s'", start_date, end_date)
  )

  # Score filters
  where_clauses <- c(where_clauses, sprintf("score >= %d", min_score))
  if (!is.null(max_score)) {
    where_clauses <- c(where_clauses, sprintf("score <= %d", max_score))
  }

  # Remove deleted/removed
  if (remove_deleted) {
    where_clauses <- c(where_clauses, "body NOT IN ('[deleted]', '[removed]')")
  }

  # Keyword filter
  if (!is.null(keywords)) {
    keyword_conditions <- paste(
      sprintf("body LIKE '%%%s%%'", keywords),
      collapse = " OR "
    )
    where_clauses <- c(where_clauses, sprintf("(%s)", keyword_conditions))
  }

  # Combine WHERE clauses
  where_sql <- paste(where_clauses, collapse = " AND ")

  # Build query
  query <- sprintf("
    SELECT
      comment_id,
      submission_id,
      body,
      author,
      score,
      created_date,
      subreddit
    FROM comments
    WHERE %s
    ORDER BY created_date, score DESC
  ", where_sql)

  # Add sampling if requested
  if (!is.null(sample_size)) {
    # For SQLite, we need to do this after loading
    # (SQLite doesn't have great built-in sampling)
  }

  # Execute query
  message(sprintf("Loading comments from %s to %s...", start_date, end_date))
  comments <- dbGetQuery(conn, query)
  dbDisconnect(conn)

  # Convert to tibble and clean
  comments <- as_tibble(comments) %>%
    mutate(date = as.Date(created_date))

  # Apply sampling if requested
  if (!is.null(sample_size) && nrow(comments) > sample_size) {
    message(sprintf("Sampling %d comments from %d total", sample_size, nrow(comments)))
    comments <- comments %>%
      sample_n(sample_size)
  }

  message(sprintf("Loaded %d comments", nrow(comments)))
  return(comments)
}


#' Get daily aggregated statistics
#'
#' Returns summary statistics for each day without loading individual comments.
#' This is much faster than loading all comments and aggregating in R.
#'
#' @param start_date Start date
#' @param end_date End date
#' @param db_path Path to database
#'
#' @return Tibble with daily statistics
#' @export
#'
#' @examples
#' daily_stats <- get_daily_stats("2021-01-13", "2021-01-31")
get_daily_stats <- function(start_date = "2021-01-13",
                           end_date = "2021-01-31",
                           db_path = DB_PATH) {

  conn <- connect_db(db_path)

  stats <- dbGetQuery(conn, sprintf("
    SELECT
      created_date as date,
      COUNT(*) as n_comments,
      AVG(score) as avg_score,
      MAX(score) as max_score,
      MIN(score) as min_score,
      SUM(CASE WHEN score > 100 THEN 1 ELSE 0 END) as high_score_count,
      SUM(CASE WHEN score < 0 THEN 1 ELSE 0 END) as negative_score_count,
      SUM(CASE WHEN LENGTH(body) > 500 THEN 1 ELSE 0 END) as long_comment_count,
      SUM(CASE WHEN body LIKE '%%🚀%%' THEN 1 ELSE 0 END) as rocket_emoji_count,
      SUM(CASE WHEN body LIKE '%%💎%%' THEN 1 ELSE 0 END) as diamond_emoji_count
    FROM comments
    WHERE created_date BETWEEN '%s' AND '%s'
      AND body NOT IN ('[deleted]', '[removed]')
    GROUP BY created_date
    ORDER BY created_date
  ", start_date, end_date))

  dbDisconnect(conn)

  stats <- as_tibble(stats) %>%
    mutate(date = as.Date(date))

  return(stats)
}


#' Get comments for a specific date
#'
#' Convenience function to load all comments from a single day
#'
#' @param date Date to load (character or Date object)
#' @param db_path Path to database
#'
#' @return Tibble with comments
#' @export
#'
#' @examples
#' jan_27_comments <- get_comments_for_date("2021-01-27")
get_comments_for_date <- function(date, db_path = DB_PATH) {
  load_comments(
    start_date = date,
    end_date = date,
    db_path = db_path
  )
}


#' Search comments by keyword
#'
#' Search for comments containing specific keywords
#'
#' @param keywords Vector of keywords to search for
#' @param start_date Start date (optional)
#' @param end_date End date (optional)
#' @param case_sensitive Whether search should be case-sensitive
#' @param db_path Path to database
#'
#' @return Tibble with matching comments
#' @export
#'
#' @examples
#' gme_mentions <- search_comments(c("GME", "GameStop"))
#' rocket_comments <- search_comments("🚀")
search_comments <- function(keywords,
                           start_date = "2021-01-01",
                           end_date = "2021-12-31",
                           case_sensitive = FALSE,
                           db_path = DB_PATH) {

  load_comments(
    start_date = start_date,
    end_date = end_date,
    keywords = keywords,
    db_path = db_path
  )
}


#' Get top comments by score
#'
#' Returns the highest-scored comments in the database
#'
#' @param n Number of comments to return
#' @param start_date Start date (optional)
#' @param end_date End date (optional)
#' @param db_path Path to database
#'
#' @return Tibble with top comments
#' @export
#'
#' @examples
#' top_100 <- get_top_comments(100)
get_top_comments <- function(n = 100,
                            start_date = "2021-01-01",
                            end_date = "2021-12-31",
                            db_path = DB_PATH) {

  conn <- connect_db(db_path)

  query <- sprintf("
    SELECT *
    FROM comments
    WHERE created_date BETWEEN '%s' AND '%s'
      AND body NOT IN ('[deleted]', '[removed]')
    ORDER BY score DESC
    LIMIT %d
  ", start_date, end_date, n)

  comments <- dbGetQuery(conn, query)
  dbDisconnect(conn)

  comments <- as_tibble(comments) %>%
    mutate(date = as.Date(created_date))

  return(comments)
}


#' Get database info
#'
#' Display information about the database contents
#'
#' @param db_path Path to database
#' @export
#'
#' @examples
#' get_db_info()
get_db_info <- function(db_path = DB_PATH) {

  if (!file.exists(db_path)) {
    cat(sprintf("Database not found: %s\n", db_path))
    return(invisible(NULL))
  }

  conn <- connect_db(db_path)

  cat("=" , rep("=", 58), "=\n", sep = "")
  cat("DATABASE INFO\n")
  cat("=" , rep("=", 58), "=\n", sep = "")

  cat(sprintf("\nDatabase: %s\n", normalizePath(db_path)))
  cat(sprintf("Size: %.2f MB\n", file.size(db_path) / 1024 / 1024))

  # Tables
  tables <- dbListTables(conn)
  cat(sprintf("\nTables: %s\n", paste(tables, collapse = ", ")))

  # Comment count
  n_comments <- dbGetQuery(conn, "SELECT COUNT(*) as n FROM comments")$n
  cat(sprintf("\nTotal comments: %s\n", format(n_comments, big.mark = ",")))

  # Date range
  date_range <- dbGetQuery(conn, "
    SELECT MIN(created_date) as min, MAX(created_date) as max
    FROM comments
  ")
  cat(sprintf("Date range: %s to %s\n", date_range$min, date_range$max))

  # Submissions (if any)
  n_submissions <- dbGetQuery(conn, "SELECT COUNT(*) as n FROM submissions")$n
  if (n_submissions > 0) {
    cat(sprintf("\nTotal submissions: %s\n", format(n_submissions, big.mark = ",")))
  }

  # Scraping history
  scrapes <- dbGetQuery(conn, "
    SELECT COUNT(*) as n FROM scrape_metadata WHERE status = 'success'
  ")
  if (scrapes$n > 0) {
    cat(sprintf("\nSuccessful scrapes: %d\n", scrapes$n))
  }

  dbDisconnect(conn)

  cat("=" , rep("=", 58), "=\n", sep = "")

  invisible(NULL)
}


#' Run a custom SQL query
#'
#' For advanced users who want to write their own SQL queries
#'
#' @param query SQL query string
#' @param db_path Path to database
#'
#' @return Query results as tibble
#' @export
#'
#' @examples
#' result <- run_query("SELECT * FROM comments WHERE score > 1000")
run_query <- function(query, db_path = DB_PATH) {
  conn <- connect_db(db_path)
  result <- dbGetQuery(conn, query)
  dbDisconnect(conn)
  return(as_tibble(result))
}


# CONVENIENCE FUNCTIONS -------------------------------------------------------

#' Load all GME-related comments
#'
#' Convenience function to load comments mentioning GME or GameStop
#'
#' @export
load_gme_comments <- function(start_date = "2021-01-01",
                              end_date = "2021-12-31") {
  load_comments(
    start_date = start_date,
    end_date = end_date,
    keywords = c("GME", "GameStop", "Gamestop")
  )
}


# PRINT INFO ON LOAD ----------------------------------------------------------

if (interactive()) {
  if (file.exists(DB_PATH)) {
    cat("\n")
    cat("Database helper functions loaded!\n")
    cat("\nMain functions:\n")
    cat("  load_comments()     - Load comments with filters\n")
    cat("  get_daily_stats()   - Get daily aggregated statistics\n")
    cat("  search_comments()   - Search by keyword\n")
    cat("  get_top_comments()  - Get highest-scored comments\n")
    cat("  get_db_info()       - Display database information\n")
    cat("\nExamples:\n")
    cat("  comments <- load_comments('2021-01-13', '2021-01-31')\n")
    cat("  daily <- get_daily_stats('2021-01-13', '2021-01-31')\n")
    cat("  gme <- search_comments(c('GME', 'GameStop'))\n")
    cat("\nFor help: ?load_comments\n")
    cat("\n")
  } else {
    cat("\n")
    cat("⚠️  Database not found:", DB_PATH, "\n")
    cat("Please create the database first:\n")
    cat("  1. Run: python setup_database.py\n")
    cat("  2. Import data: python migrate_csv_to_db.py\n")
    cat("  3. Or scrape new data: python scrape_reddit_to_db.py\n")
    cat("\n")
  }
}
