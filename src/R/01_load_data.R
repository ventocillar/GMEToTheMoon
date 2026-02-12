# ==============================================================================
# 01_load_data.R
# Load daily activity metrics from SQLite (lightweight -- no full text in RAM)
# ==============================================================================

message("=== 01: Loading activity data from SQLite ===")

conn <- get_db_connection()

# --- Daily activity metrics (aggregated in SQL -- memory efficient) ------------

daily_activity <- dbGetQuery(conn, sprintf(
  "SELECT
     date,
     COUNT(*) as n_comments,
     COUNT(DISTINCT author) as n_authors,
     AVG(score) as avg_score,
     CAST(SUM(score) AS REAL) as total_score
   FROM comments
   WHERE date >= '%s' AND date <= '%s'
   GROUP BY date
   ORDER BY date",
  STUDY_START, STUDY_END
))

daily_activity <- daily_activity %>%
  mutate(
    date = as.Date(date),
    median_score = NA_real_  # Would require loading all data; skip for efficiency
  )

# --- Summary stats ------------------------------------------------------------

n_comments_total <- sum(daily_activity$n_comments)
date_range <- range(daily_activity$date)
n_days <- nrow(daily_activity)

message(sprintf(
  "  %s comments from %s to %s (%d days)",
  format(n_comments_total, big.mark = ","),
  date_range[1], date_range[2], n_days
))

# --- Check for gaps -----------------------------------------------------------

all_dates <- seq(STUDY_START, STUDY_END, by = "day")
missing_dates <- all_dates[!all_dates %in% daily_activity$date]
if (length(missing_dates) > 0) {
  message("  Warning: ", length(missing_dates), " dates with no comments")
}

dbDisconnect(conn)
message("Data loading complete.\n")
