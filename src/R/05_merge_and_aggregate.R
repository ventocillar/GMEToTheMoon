# ==============================================================================
# 05_merge_and_aggregate.R
# Merge daily sentiment with stock returns to create master analysis dataset
# ==============================================================================

message("=== 05: Merging sentiment with financial data ===")

# --- Pivot sentiment to wide format -------------------------------------------

sentiment_wide <- all_sentiment %>%
  filter(weight_type == "unweighted") %>%
  mutate(col_name = paste0(lexicon, "_", emotion)) %>%
  select(date, col_name, raw_count, normalized) %>%
  pivot_wider(
    id_cols = date,
    names_from = col_name,
    values_from = c(raw_count, normalized),
    values_fill = 0
  )

# Weighted versions (prefix with "w_")
sentiment_wide_w <- all_sentiment %>%
  filter(weight_type == "weighted") %>%
  mutate(col_name = paste0("w_", lexicon, "_", emotion)) %>%
  select(date, col_name, weighted_count) %>%
  pivot_wider(
    id_cols = date,
    names_from = col_name,
    values_from = weighted_count,
    values_fill = 0
  )

# --- Compute composite sentiment scores --------------------------------------

composite_sentiment <- all_sentiment %>%
  filter(weight_type == "unweighted") %>%
  filter(
    (lexicon == "nrc" & emotion %in% c("positive", "negative")) |
    (lexicon == "bing" & emotion %in% c("positive", "negative"))
  ) %>%
  select(date, lexicon, emotion, raw_count) %>%
  pivot_wider(names_from = c(lexicon, emotion), values_from = raw_count, values_fill = 0) %>%
  mutate(
    nrc_net   = nrc_positive - nrc_negative,
    bing_net  = bing_positive - bing_negative,
    # Guard against division by zero
    nrc_ratio  = ifelse((nrc_positive + nrc_negative) > 0,
                        nrc_positive / (nrc_positive + nrc_negative), NA_real_),
    bing_ratio = ifelse((bing_positive + bing_negative) > 0,
                        bing_positive / (bing_positive + bing_negative), NA_real_)
  ) %>%
  select(date, nrc_net, bing_net, nrc_ratio, bing_ratio)

# --- Extract AFINN/WSB/Emoji scores -------------------------------------------
# For numeric lexicons (AFINN, WSB, emoji), weighted_count holds sum(value)
# even when unweighted -- this IS the sentiment score, not a count.
# raw_count is just the number of matched words.

score_sentiment <- all_sentiment %>%
  filter(weight_type == "unweighted",
         lexicon %in% c("afinn", "wsb_custom", "emoji"),
         emotion == "score") %>%
  select(date, lexicon, weighted_count) %>%
  pivot_wider(names_from = lexicon, values_from = weighted_count, values_fill = 0) %>%
  rename(afinn_score = afinn, wsb_score = wsb_custom, emoji_score = emoji)

# --- Merge everything ---------------------------------------------------------

master_df <- daily_activity %>%
  left_join(gme_prices, by = "date") %>%
  left_join(sentiment_wide, by = "date") %>%
  left_join(sentiment_wide_w, by = "date") %>%
  left_join(composite_sentiment, by = "date") %>%
  left_join(score_sentiment, by = "date") %>%
  arrange(date)

# --- Create lag variables -----------------------------------------------------

# Use config event dates instead of hardcoded
first_surge_date <- as.Date(cfg$events$first_surge)

master_df <- master_df %>%
  mutate(
    # Lagged sentiment (t-1, t-2)
    afinn_lag1 = lag(afinn_score, 1),
    afinn_lag2 = lag(afinn_score, 2),
    wsb_lag1   = lag(wsb_score, 1),
    wsb_lag2   = lag(wsb_score, 2),
    nrc_net_lag1 = lag(nrc_net, 1),
    nrc_net_lag2 = lag(nrc_net, 2),
    bing_net_lag1 = lag(bing_net, 1),
    bing_net_lag2 = lag(bing_net, 2),
    emoji_lag1 = lag(emoji_score, 1),
    emoji_lag2 = lag(emoji_score, 2),
    # Activity lags
    n_comments_lag1 = lag(n_comments, 1),
    # Return lags
    gme_return_lag1 = lag(gme_return, 1),
    gme_return_lag2 = lag(gme_return, 2),
    # Event indicators
    post_event = as.integer(date >= EVENT_DATE),
    post_surge = as.integer(date >= first_surge_date)
  )

# --- Trading days only dataset ------------------------------------------------

master_trading <- master_df %>%
  filter(!is.na(gme_return))

message(sprintf("  Master dataset: %d total days, %d trading days",
                nrow(master_df), nrow(master_trading)))
message(sprintf("  Variables: %d", ncol(master_df)))

# --- Store daily sentiment in SQLite ------------------------------------------

conn <- get_db_connection()
dbExecute(conn, "DELETE FROM daily_sentiment")

sentiment_to_db <- all_sentiment %>%
  filter(weight_type == "unweighted") %>%
  left_join(daily_activity, by = "date") %>%
  select(date, lexicon, emotion, raw_count, weighted_count, normalized,
         n_comments, n_authors, avg_score)

dbWriteTable(conn, "daily_sentiment", sentiment_to_db, append = TRUE, row.names = FALSE)
dbDisconnect(conn)

message("Merge and aggregation complete.\n")
