# ==============================================================================
# 06_descriptive_stats.R
# Summary tables, time series plots, word contribution charts
# All plots use theme_thesis() and thesis_palette from helpers/plotting_theme.R
# ==============================================================================

message("=== 06: Descriptive statistics and plots ===")

# --- Key dates from config ----------------------------------------------------

event_dates <- data.frame(
  date = as.Date(c(cfg$events$first_surge, cfg$events$peak_day,
                    cfg$events$robinhood_restriction)),
  label = c("First surge", "Peak", "RH restriction"),
  stringsAsFactors = FALSE
)

# --- Summary Statistics Table -------------------------------------------------

summary_vars <- master_trading %>%
  select(
    gme_return, gme_close, gme_volume, gme_abnormal_volume,
    n_comments, n_authors, avg_score,
    afinn_score, wsb_score, nrc_net, bing_net, emoji_score
  )

summary_table <- summary_vars %>%
  pivot_longer(everything(), names_to = "variable", values_to = "value") %>%
  group_by(variable) %>%
  summarize(
    N    = sum(!is.na(value)),
    Mean = mean(value, na.rm = TRUE),
    SD   = sd(value, na.rm = TRUE),
    Min  = min(value, na.rm = TRUE),
    Q1   = quantile(value, 0.25, na.rm = TRUE),
    Median = median(value, na.rm = TRUE),
    Q3   = quantile(value, 0.75, na.rm = TRUE),
    Max  = max(value, na.rm = TRUE),
    .groups = "drop"
  )

write_csv(summary_table, file.path(TAB_DIR, "summary_statistics.csv"))
message("  Saved summary statistics table")

# --- Plot 1: GME Price --------------------------------------------------------

p_gme_price <- gme_prices %>%
  filter(date >= STUDY_START, date <= STUDY_END) %>%
  ggplot(aes(x = date, y = gme_close)) +
  geom_line(color = thesis_palette[1], linewidth = 1) +
  geom_vline(data = event_dates, aes(xintercept = date),
             linetype = "dashed", color = thesis_colors$event, alpha = 0.7) +
  annotate("text", x = EVENT_DATE, y = Inf,
           label = "RH restriction", vjust = 2, hjust = 1.1,
           size = 3, color = thesis_colors$event) +
  scale_x_date(date_breaks = "2 weeks", date_labels = "%b %d") +
  labs(title = "GameStop Adjusted Closing Price",
       subtitle = paste(STUDY_START, "to", STUDY_END),
       x = NULL, y = "Price (USD)") +
  theme_thesis()

save_thesis_plot(p_gme_price, "gme_price_timeseries.png")

# --- Plot 2: Daily Comment Volume ---------------------------------------------

p_activity <- daily_activity %>%
  ggplot(aes(x = date, y = n_comments)) +
  geom_col(fill = thesis_palette[3], alpha = 0.7) +
  geom_vline(data = event_dates, aes(xintercept = date),
             linetype = "dashed", color = thesis_colors$event, alpha = 0.7) +
  scale_x_date(date_breaks = "2 weeks", date_labels = "%b %d") +
  scale_y_continuous(labels = comma) +
  labs(title = "Daily r/WallStreetBets Comment Volume",
       x = NULL, y = "Number of Comments") +
  theme_thesis()

save_thesis_plot(p_activity, "daily_comment_volume.png")

# --- Plot 3: NRC Emotions Time Series -----------------------------------------

nrc_emotions_daily <- all_sentiment %>%
  filter(lexicon == "nrc", weight_type == "unweighted",
         !emotion %in% c("positive", "negative")) %>%
  select(date, emotion, normalized)

n_emotions <- n_distinct(nrc_emotions_daily$emotion)

p_nrc_emotions <- nrc_emotions_daily %>%
  ggplot(aes(x = date, y = normalized, color = emotion)) +
  geom_line(linewidth = 0.8, alpha = 0.8) +
  geom_vline(xintercept = EVENT_DATE,
             linetype = "dashed", color = thesis_colors$event, alpha = 0.7) +
  scale_color_manual(values = thesis_palette[1:n_emotions]) +
  scale_x_date(date_breaks = "2 weeks", date_labels = "%b %d") +
  labs(title = "NRC Emotion Intensity Over Time (Normalized)",
       subtitle = "Proportion of emotion words per total comments",
       x = NULL, y = "Normalized Count", color = "Emotion") +
  theme_thesis()

save_thesis_plot(p_nrc_emotions, "nrc_emotions_timeseries.png")

# --- Plot 4: Positive vs Negative (NRC and BING) -----------------------------

p_posneg <- all_sentiment %>%
  filter(weight_type == "unweighted",
         (lexicon == "nrc" & emotion %in% c("positive", "negative")) |
         (lexicon == "bing" & emotion %in% c("positive", "negative"))) %>%
  mutate(label = paste(lexicon, emotion, sep = " ")) %>%
  ggplot(aes(x = date, y = normalized, color = label)) +
  geom_line(linewidth = 0.8, alpha = 0.8) +
  geom_point(size = 0.3, alpha = 0.4) +
  geom_vline(xintercept = EVENT_DATE,
             linetype = "dashed", color = thesis_colors$event, alpha = 0.7) +
  scale_color_manual(values = thesis_palette[c(1, 4, 2, 7)]) +
  scale_x_date(date_breaks = "2 weeks", date_labels = "%b %d") +
  labs(title = "Positive vs. Negative Sentiment (NRC & BING)",
       x = NULL, y = "Normalized Count", color = NULL) +
  theme_thesis()

save_thesis_plot(p_posneg, "positive_negative_timeseries.png")

# --- Plot 5: Sentiment-Return Overlay -----------------------------------------

p_overlay <- master_trading %>%
  filter(!is.na(afinn_score)) %>%
  select(date, gme_return, afinn_score) %>%
  mutate(
    gme_return_z = scale(gme_return)[,1],
    afinn_z = scale(afinn_score)[,1]
  ) %>%
  pivot_longer(c(gme_return_z, afinn_z), names_to = "series", values_to = "value") %>%
  mutate(series = recode(series,
    "gme_return_z" = "GME Daily Return (std.)",
    "afinn_z"      = "AFINN Sentiment (std.)"
  )) %>%
  ggplot(aes(x = date, y = value, color = series)) +
  geom_line(linewidth = 1, alpha = 0.8) +
  geom_hline(yintercept = 0, linetype = "dotted", color = "grey50") +
  geom_vline(xintercept = EVENT_DATE,
             linetype = "dashed", color = thesis_colors$event, alpha = 0.7) +
  scale_color_manual(values = c(thesis_palette[1], thesis_palette[4])) +
  scale_x_date(date_breaks = "2 weeks", date_labels = "%b %d") +
  labs(title = "Sentiment vs. GME Returns (Standardized)",
       subtitle = paste(STUDY_START, "to", STUDY_END),
       x = NULL, y = "Standard Deviations", color = NULL) +
  theme_thesis()

save_thesis_plot(p_overlay, "sentiment_return_overlay.png")

# --- Plot 6: Word Contribution to BING Sentiment -----------------------------

# Use a sample of tokens from the DB for word contribution (memory-safe)
conn <- get_db_connection()
# Get a manageable random sample for word frequency
word_sample <- dbGetQuery(conn, sprintf(
  "SELECT body, date FROM comments
   WHERE date >= '%s' AND date <= '%s'
   ORDER BY RANDOM() LIMIT 500000",
  STUDY_START, STUDY_END
))
dbDisconnect(conn)

word_tokens <- word_sample %>%
  rename(text = body) %>%
  mutate(text = str_replace_all(text, "https?://\\S+", "")) %>%
  unnest_tokens(word, text) %>%
  anti_join(all_stop_words, by = "word") %>%
  filter(!str_detect(word, "^\\d+$"), nchar(word) > 1)

bing_word_contrib <- word_tokens %>%
  inner_join(get_sentiments("bing"), by = "word") %>%
  count(word, sentiment, sort = TRUE) %>%
  group_by(sentiment) %>%
  slice_max(n, n = 20) %>%
  ungroup() %>%
  mutate(word = reorder(word, n))

rm(word_sample, word_tokens)
gc()

p_bing_words <- bing_word_contrib %>%
  ggplot(aes(x = n, y = word, fill = sentiment)) +
  geom_col(show.legend = FALSE) +
  scale_fill_manual(values = c("negative" = thesis_palette[4],
                                "positive" = thesis_palette[1])) +
  facet_wrap(~ sentiment, scales = "free_y") +
  labs(title = "Top Words Contributing to BING Sentiment",
       subtitle = "Based on 500K random comment sample",
       x = "Frequency", y = NULL) +
  theme_thesis()

save_thesis_plot(p_bing_words, "bing_word_contribution.png")

# --- Plot 7: Emoji Frequency -------------------------------------------------

p_emoji_freq <- emoji_freq %>%
  head(20) %>%
  mutate(emoji = fct_reorder(emoji, n)) %>%
  ggplot(aes(x = n, y = emoji)) +
  geom_col(fill = thesis_palette[2]) +
  scale_x_continuous(labels = comma) +
  labs(title = "Most Frequent Emojis in WSB Comments",
       x = "Count", y = NULL) +
  theme_thesis()

save_thesis_plot(p_emoji_freq, "emoji_frequency.png")

# --- Plot 8: Meme vs Control Stock Prices -------------------------------------

n_meme <- length(MEME_STOCKS)

p_meme_stocks <- stock_prices %>%
  filter(symbol %in% MEME_STOCKS,
         date >= STUDY_START, date <= STUDY_END) %>%
  ggplot(aes(x = date, y = adjusted, color = symbol)) +
  geom_line(linewidth = 1, alpha = 0.8) +
  geom_vline(xintercept = EVENT_DATE,
             linetype = "dashed", color = thesis_colors$event, alpha = 0.7) +
  scale_color_manual(values = thesis_palette[1:n_meme]) +
  scale_x_date(date_breaks = "2 weeks", date_labels = "%b %d") +
  facet_wrap(~ symbol, scales = "free_y", ncol = 2) +
  labs(title = "Meme Stock Prices",
       subtitle = paste(STUDY_START, "to", STUDY_END),
       x = NULL, y = "Adjusted Close", color = "Symbol") +
  theme_thesis() +
  theme(legend.position = "none")

save_thesis_plot(p_meme_stocks, "meme_stocks_prices.png")

# --- Plot 9: WSB Custom Sentiment Over Time -----------------------------------

wsb_daily <- all_sentiment %>%
  filter(lexicon == "wsb_custom", emotion == "score", weight_type == "unweighted") %>%
  select(date, wsb_sentiment = weighted_count)

p_wsb_sentiment <- wsb_daily %>%
  ggplot(aes(x = date, y = wsb_sentiment)) +
  geom_col(aes(fill = wsb_sentiment > 0), show.legend = FALSE, alpha = 0.8) +
  scale_fill_manual(values = c("TRUE" = thesis_palette[1], "FALSE" = thesis_palette[4])) +
  geom_vline(data = event_dates, aes(xintercept = date),
             linetype = "dashed", color = thesis_colors$event, alpha = 0.7) +
  scale_x_date(date_breaks = "2 weeks", date_labels = "%b %d") +
  scale_y_continuous(labels = comma) +
  labs(title = "WSB Custom Lexicon: Daily Net Sentiment",
       subtitle = "Green = net bullish, Red = net bearish",
       x = NULL, y = "Net Sentiment Score") +
  theme_thesis()

save_thesis_plot(p_wsb_sentiment, "wsb_custom_sentiment.png")

message("Descriptive statistics complete.\n")
