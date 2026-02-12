# ==============================================================================
# 03_sentiment_analysis.R
# Compute sentiment for each monthly chunk from 02_preprocess, then free tokens.
# Memory-efficient: processes one month at a time, keeps only daily aggregates.
# ==============================================================================

message("=== 03: Computing sentiment scores (chunked) ===")

# --- Process each monthly chunk -----------------------------------------------

sentiment_results <- list()

for (i in seq_along(all_tokens_daily)) {
  chunk_tokens <- all_tokens_daily[[i]]
  if (is.null(chunk_tokens) || nrow(chunk_tokens) == 0) next

  month_label <- format(min(chunk_tokens$date), "%Y-%m")
  message(sprintf("  Sentiment for %s (%s tokens)...",
                  month_label, format(nrow(chunk_tokens), big.mark = ",")))

  # Unweighted
  sent_uw <- compute_all_sentiments(
    tokens_df = chunk_tokens,
    emoji_df = emoji_extracted %>% filter(date %in% unique(chunk_tokens$date)),
    weight_by_score = FALSE
  )
  sent_uw$weight_type <- "unweighted"

  # Weighted
  sent_w <- compute_all_sentiments(
    tokens_df = chunk_tokens,
    emoji_df = emoji_extracted %>% filter(date %in% unique(chunk_tokens$date)),
    weight_by_score = TRUE
  )
  sent_w$weight_type <- "weighted"

  sentiment_results[[i]] <- bind_rows(sent_uw, sent_w)

  # Free this month's tokens (use list(NULL) to keep index, not shift list)
  all_tokens_daily[i] <- list(NULL)
  rm(chunk_tokens, sent_uw, sent_w)
  gc()
}

# Free the token list entirely
rm(all_tokens_daily)
gc()

# --- Combine all sentiment results --------------------------------------------

all_sentiment <- bind_rows(sentiment_results)
rm(sentiment_results)
gc()

# --- Normalize by daily comment volume ----------------------------------------

all_sentiment <- normalize_sentiment(all_sentiment, daily_activity)

# --- Summary ------------------------------------------------------------------

sentiment_summary <- all_sentiment %>%
  group_by(lexicon, weight_type) %>%
  summarize(
    n_days = n_distinct(date),
    total_raw_count = sum(raw_count, na.rm = TRUE),
    .groups = "drop"
  )

message("  Sentiment computed for ", n_distinct(all_sentiment$lexicon), " lexicons:")
message("  ", paste(unique(all_sentiment$lexicon), collapse = ", "))

message("Sentiment analysis complete.\n")
