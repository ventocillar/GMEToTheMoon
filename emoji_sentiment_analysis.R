# ============================================================================
# EMOJI SENTIMENT ANALYSIS - READY TO USE
# ============================================================================
# This script extracts and analyzes emoji sentiment from WSB comments
# Integrates with your existing sentiment analysis
# ============================================================================

# SETUP -----------------------------------------------------------------------

library(tidyverse)
library(readxl)
library(tidytext)
library(stringi)
library(tidyquant)
library(lmtest)
library(sandwich)
library(modelsummary)
library(MetBrewer)

# EMOJI DICTIONARY ------------------------------------------------------------

# WSB-Specific Emoji Sentiment Dictionary
# Based on WSB culture and trading terminology
wsb_emoji_dict <- tibble(
  emoji = c(
    # VERY BULLISH (value: 3)
    "🚀",  # Rocket - "to the moon"
    "💎",  # Diamond - "diamond hands"

    # BULLISH (value: 2)
    "🙌",  # Raised hands - usually with diamond
    "🌙",  # Moon - price target
    "📈",  # Chart increasing
    "💰",  # Money bag
    "🤑",  # Money face
    "💵",  # Dollar bill
    "🐂",  # Bull
    "💪",  # Strong/flexed bicep

    # MODERATELY BULLISH (value: 1.5)
    "🦍",  # Ape - "apes together strong"
    "🔥",  # Fire - hot stock
    "⭐",  # Star
    "✨",  # Sparkles
    "💸",  # Money with wings

    # MILDLY BULLISH (value: 1)
    "👍",  # Thumbs up
    "🎉",  # Party
    "🌟",  # Glowing star
    "👏",  # Clapping
    "😎",  # Cool
    "🤝",  # Handshake

    # BEARISH/NEGATIVE (value: -2)
    "🐻",  # Bear
    "📉",  # Chart decreasing
    "💩",  # Poop
    "🧻",  # Toilet paper - "paper hands"
    "💀",  # Skull - dead/killed
    "☠️",  # Skull and crossbones

    # MODERATELY BEARISH (value: -1.5)
    "⚠️",  # Warning
    "😱",  # Screaming in fear
    "😭",  # Crying
    "❌",  # X mark

    # MILDLY BEARISH (value: -1)
    "👎",  # Thumbs down
    "😞",  # Disappointed
    "😢",  # Crying face
    "🤦",  # Facepalm
    "💔"   # Broken heart
  ),
  sentiment_value = c(
    # Bullish values
    3, 3,
    2, 2, 2, 2, 2, 2, 2, 2,
    1.5, 1.5, 1.5, 1.5, 1.5,
    1, 1, 1, 1, 1, 1,
    # Bearish values
    -2, -2, -2, -2, -2, -2,
    -1.5, -1.5, -1.5, -1.5,
    -1, -1, -1, -1, -1
  ),
  emoji_name = c(
    "rocket", "diamond",
    "hands", "moon", "chart_up", "money_bag", "money_face", "dollar",
    "bull", "muscle",
    "ape", "fire", "star", "sparkles", "money_wings",
    "thumbs_up", "party", "star_glow", "clap", "cool", "handshake",
    "bear", "chart_down", "poop", "paper", "skull", "skull_bones",
    "warning", "scream", "cry", "x_mark",
    "thumbs_down", "disappointed", "tear", "facepalm", "broken_heart"
  )
)

# Save dictionary for reference
write_csv(wsb_emoji_dict, "wsb_emoji_sentiment_dictionary.csv")

cat("Created emoji dictionary with", nrow(wsb_emoji_dict), "emojis\n")
cat("Average sentiment:", round(mean(wsb_emoji_dict$sentiment_value), 2), "\n\n")


# SPECIAL COMBINATIONS --------------------------------------------------------

# Some emoji combinations have special meaning
wsb_emoji_combos <- tibble(
  pattern = c("💎🙌", "💎✋", "🚀🚀", "🚀🚀🚀", "🚀🌙", "📈💰", "🧻🙌", "📉💩"),
  sentiment_boost = c(2, 2, 1, 2, 1, 1, -1, -1),
  combo_name = c("diamond_hands", "diamond_hands_alt", "double_rocket",
                 "triple_rocket", "moon_rocket", "gains",
                 "paper_hands", "crash")
)


# EXTRACTION FUNCTIONS --------------------------------------------------------

#' Extract emojis from text using Unicode ranges
#'
#' @param text Character vector of comments
#' @return List of emojis for each comment
extract_emojis <- function(text) {

  # Unicode pattern for emojis (covers most emoji ranges)
  emoji_pattern <- "[\\x{1F300}-\\x{1F6FF}\\x{2600}-\\x{26FF}\\x{2700}-\\x{27BF}\\x{1F900}-\\x{1F9FF}\\x{1F1E0}-\\x{1F1FF}\\x{1FA00}-\\x{1FAFF}]"

  # Extract all emojis
  emojis <- stri_extract_all_regex(text, emoji_pattern)

  return(emojis)
}


#' Calculate emoji sentiment for individual comments
#'
#' @param text Character vector of comments
#' @param emoji_dict Emoji sentiment dictionary
#' @return Data frame with emoji counts and sentiment
calculate_emoji_features <- function(text, emoji_dict = wsb_emoji_dict) {

  # Extract emojis
  emoji_list <- extract_emojis(text)

  # Create data frame
  emoji_df <- tibble(
    row_id = seq_along(text),
    text = text,
    emojis = emoji_list
  ) %>%
    mutate(
      # Count total emojis
      n_emojis = map_int(emojis, length),
      # Check for specific patterns
      has_rocket = map_lgl(text, ~str_detect(.x, "🚀")),
      n_rockets = map_int(text, ~str_count(.x, "🚀")),
      has_diamond_hands = map_lgl(text, ~str_detect(.x, "💎") & str_detect(.x, "🙌|✋")),
      has_moon = map_lgl(text, ~str_detect(.x, "🌙"))
    )

  # Calculate sentiment
  emoji_sentiment <- emoji_df %>%
    unnest(emojis) %>%
    left_join(emoji_dict, by = c("emojis" = "emoji")) %>%
    group_by(row_id) %>%
    summarize(
      emoji_sentiment = sum(sentiment_value, na.rm = TRUE),
      n_emojis_matched = sum(!is.na(sentiment_value)),
      n_emojis_unmatched = sum(is.na(sentiment_value)),
      .groups = "drop"
    )

  # Merge back
  result <- emoji_df %>%
    select(row_id, n_emojis, has_rocket, n_rockets, has_diamond_hands, has_moon) %>%
    left_join(emoji_sentiment, by = "row_id") %>%
    mutate(
      emoji_sentiment = replace_na(emoji_sentiment, 0),
      n_emojis_matched = replace_na(n_emojis_matched, 0),
      n_emojis_unmatched = replace_na(n_emojis_unmatched, 0),
      # Intensity score (account for multiple rockets)
      emoji_intensity = log(n_rockets + 1) * 2 +
                        as.numeric(has_diamond_hands) * 3 +
                        as.numeric(has_moon) * 1.5
    )

  return(result)
}


#' Calculate combined text and emoji sentiment
#'
#' @param comments_df Data frame with body, date, score
#' @param text_dict Text sentiment dictionary (default: BING)
#' @param emoji_dict Emoji sentiment dictionary
#' @param weight_by_score Whether to weight by comment score
#' @return Data frame with sentiment features
calculate_combined_sentiment <- function(comments_df,
                                         text_dict = get_sentiments("bing"),
                                         emoji_dict = wsb_emoji_dict,
                                         weight_by_score = TRUE) {

  cat("Processing", nrow(comments_df), "comments...\n")

  # Add row IDs
  comments_df <- comments_df %>%
    mutate(row_id = row_number())

  # === TEXT SENTIMENT ===
  cat("Calculating text sentiment...\n")

  text_tokens <- comments_df %>%
    unnest_tokens(word, body, to_lower = TRUE, token = "words")

  # Remove stop words
  data(stop_words)
  custom_stops <- tibble(word = c("deleted", "removed"), lexicon = "custom")
  stop_words_extended <- bind_rows(stop_words, custom_stops)

  text_tokens <- text_tokens %>%
    anti_join(stop_words_extended, by = "word")

  text_sentiment <- text_tokens %>%
    inner_join(text_dict, by = "word") %>%
    mutate(sentiment_value = ifelse(sentiment == "positive", 1, -1)) %>%
    group_by(row_id, date) %>%
    summarize(
      text_sentiment = sum(sentiment_value),
      n_words_matched = n(),
      .groups = "drop"
    )

  # === EMOJI SENTIMENT ===
  cat("Calculating emoji sentiment...\n")

  emoji_features <- calculate_emoji_features(
    text = comments_df$body,
    emoji_dict = emoji_dict
  )

  # === COMBINE ===
  cat("Combining sentiment measures...\n")

  combined <- comments_df %>%
    left_join(text_sentiment, by = c("row_id", "date")) %>%
    left_join(emoji_features, by = "row_id") %>%
    mutate(
      # Fill NAs
      text_sentiment = replace_na(text_sentiment, 0),
      emoji_sentiment = replace_na(emoji_sentiment, 0),
      n_words_matched = replace_na(n_words_matched, 0),
      n_emojis = replace_na(n_emojis, 0),
      emoji_intensity = replace_na(emoji_intensity, 0),

      # Combined sentiment (additive)
      combined_sentiment = text_sentiment + emoji_sentiment,

      # Alternative: weighted average
      combined_weighted = 0.5 * text_sentiment + 0.5 * emoji_sentiment,

      # Intensity-adjusted (emojis get more weight if many are used)
      combined_intensity = text_sentiment + emoji_sentiment * (1 + log(n_emojis + 1))
    )

  # Weight by score if available
  if (weight_by_score && "score" %in% names(combined)) {
    cat("Weighting by comment scores...\n")
    combined <- combined %>%
      mutate(
        score_weight = log(score + 1),
        text_sentiment_weighted = text_sentiment * score_weight,
        emoji_sentiment_weighted = emoji_sentiment * score_weight,
        combined_sentiment_weighted = combined_sentiment * score_weight,
        combined_intensity_weighted = combined_intensity * score_weight
      )
  }

  cat("Done!\n\n")
  return(combined)
}


#' Aggregate sentiment to daily level
#'
#' @param sentiment_df Output from calculate_combined_sentiment
#' @return Daily aggregated sentiment
aggregate_daily_sentiment <- function(sentiment_df) {

  has_weights <- "score_weight" %in% names(sentiment_df)

  if (has_weights) {
    daily <- sentiment_df %>%
      group_by(date) %>%
      summarize(
        # Unweighted
        text_sentiment = sum(text_sentiment),
        emoji_sentiment = sum(emoji_sentiment),
        combined_sentiment = sum(combined_sentiment),
        combined_intensity = sum(combined_intensity),

        # Weighted
        text_sentiment_weighted = sum(text_sentiment_weighted),
        emoji_sentiment_weighted = sum(emoji_sentiment_weighted),
        combined_sentiment_weighted = sum(combined_sentiment_weighted),
        combined_intensity_weighted = sum(combined_intensity_weighted),

        # Counts
        n_comments = n(),
        total_emojis = sum(n_emojis),
        total_words = sum(n_words_matched),
        n_with_emojis = sum(n_emojis > 0),
        n_with_rockets = sum(has_rocket, na.rm = TRUE),
        n_with_diamond_hands = sum(has_diamond_hands, na.rm = TRUE),

        # Ratios
        pct_with_emojis = n_with_emojis / n_comments * 100,
        emojis_per_comment = total_emojis / n_comments,
        avg_emoji_intensity = mean(emoji_intensity, na.rm = TRUE),

        .groups = "drop"
      )
  } else {
    daily <- sentiment_df %>%
      group_by(date) %>%
      summarize(
        text_sentiment = sum(text_sentiment),
        emoji_sentiment = sum(emoji_sentiment),
        combined_sentiment = sum(combined_sentiment),
        combined_intensity = sum(combined_intensity),
        n_comments = n(),
        total_emojis = sum(n_emojis),
        n_with_emojis = sum(n_emojis > 0),
        pct_with_emojis = n_with_emojis / n_comments * 100,
        emojis_per_comment = total_emojis / n_comments,
        .groups = "drop"
      )
  }

  return(daily)
}


# LOAD AND PROCESS DATA -------------------------------------------------------

cat("=== LOADING DATA ===\n\n")

# Load your Reddit data
# Adjust file path as needed
my_gamestop_scores <- read_excel("comments_13-31_Jan_withscore.xlsx")

# Clean data
my_gamestop_clean <- my_gamestop_scores %>%
  select(body, date, score) %>%
  mutate(date = as.Date(date)) %>%
  filter(
    !body %in% c("[deleted]", "[removed]"),
    !is.na(body),
    nchar(body) > 5
  )

cat("Loaded", nrow(my_gamestop_clean), "comments\n")
cat("Date range:", as.character(min(my_gamestop_clean$date)),
    "to", as.character(max(my_gamestop_clean$date)), "\n\n")


# CALCULATE SENTIMENT ---------------------------------------------------------

cat("=== CALCULATING SENTIMENT ===\n\n")

# Calculate combined sentiment
sentiment_combined <- calculate_combined_sentiment(
  comments_df = my_gamestop_clean,
  text_dict = get_sentiments("bing"),
  emoji_dict = wsb_emoji_dict,
  weight_by_score = TRUE
)

# Aggregate to daily
sentiment_daily <- aggregate_daily_sentiment(sentiment_combined)

cat("Summary Statistics:\n")
print(summary(sentiment_daily))


# SAVE RESULTS ----------------------------------------------------------------

# Save comment-level data
write_csv(sentiment_combined, "output/comment_level_sentiment_with_emojis.csv")

# Save daily aggregates
write_csv(sentiment_daily, "output/daily_sentiment_with_emojis.csv")

cat("\nResults saved to output/ directory\n")


# VISUALIZATIONS --------------------------------------------------------------

cat("\n=== CREATING VISUALIZATIONS ===\n\n")

# Create output directory if needed
dir.create("output/figures", showWarnings = FALSE, recursive = TRUE)

# 1. Text vs Emoji Sentiment Over Time
plot1 <- sentiment_daily %>%
  select(date, text_sentiment, emoji_sentiment, combined_sentiment) %>%
  pivot_longer(-date, names_to = "type", values_to = "sentiment") %>%
  mutate(type = recode(type,
                       text_sentiment = "Text Only",
                       emoji_sentiment = "Emoji Only",
                       combined_sentiment = "Combined")) %>%
  ggplot(aes(x = date, y = sentiment, color = type)) +
  geom_line(size = 1.2, alpha = 0.8) +
  geom_point(size = 2.5, alpha = 0.7) +
  geom_vline(xintercept = as.Date("2021-01-28"),
             linetype = "dashed", alpha = 0.5) +
  scale_color_manual(values = met.brewer("Veronese", 3)) +
  scale_x_date(date_breaks = "2 days", date_labels = "%b %d") +
  labs(
    title = "Sentiment Analysis: Text vs Emojis vs Combined",
    subtitle = "r/WallStreetBets GameStop Discussion",
    x = "Date",
    y = "Daily Sentiment Score",
    color = "Sentiment Type",
    caption = "Dashed line indicates January 28 (GME peak)"
  ) +
  theme_minimal() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    legend.position = "bottom",
    plot.title = element_text(face = "bold", size = 14)
  )

ggsave("output/figures/text_vs_emoji_sentiment.png", plot1,
       width = 10, height = 6, dpi = 300)

# 2. Emoji Usage Over Time
plot2 <- ggplot(sentiment_daily, aes(x = date, y = emojis_per_comment)) +
  geom_line(size = 1.2, color = met.brewer("Veronese", 1)) +
  geom_point(size = 3, alpha = 0.7, color = met.brewer("Veronese", 1)) +
  geom_vline(xintercept = as.Date("2021-01-28"),
             linetype = "dashed", alpha = 0.5) +
  scale_x_date(date_breaks = "2 days", date_labels = "%b %d") +
  labs(
    title = "Emoji Usage Intensity Over Time",
    subtitle = "Average number of emojis per comment",
    x = "Date",
    y = "Emojis per Comment"
  ) +
  theme_minimal() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    plot.title = element_text(face = "bold", size = 14)
  )

ggsave("output/figures/emoji_usage_over_time.png", plot2,
       width = 10, height = 6, dpi = 300)

# 3. Most Common Emojis
all_emojis <- sentiment_combined %>%
  select(row_id, body) %>%
  mutate(emojis = extract_emojis(body)) %>%
  unnest(emojis) %>%
  filter(!is.na(emojis)) %>%
  count(emojis, sort = TRUE) %>%
  head(15) %>%
  left_join(wsb_emoji_dict, by = c("emojis" = "emoji"))

plot3 <- ggplot(all_emojis, aes(x = reorder(emojis, n), y = n,
                                 fill = sentiment_value)) +
  geom_col() +
  scale_fill_gradient2(
    low = "#d73027",
    mid = "#ffffbf",
    high = "#1a9850",
    midpoint = 0,
    name = "Sentiment\nValue"
  ) +
  coord_flip() +
  labs(
    title = "Top 15 Most Frequent Emojis in GME Discussion",
    subtitle = "Colored by sentiment value",
    x = "",
    y = "Frequency"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    axis.text.y = element_text(size = 20)  # Make emojis bigger
  )

ggsave("output/figures/top_emojis.png", plot3,
       width = 8, height = 10, dpi = 300)

cat("Visualizations saved to output/figures/\n\n")


# REGRESSION ANALYSIS ---------------------------------------------------------

cat("=== REGRESSION ANALYSIS ===\n\n")

# Get stock returns
gme_returns <- tq_get("GME",
                      from = min(sentiment_daily$date) - days(5),
                      to = max(sentiment_daily$date) + days(5)) %>%
  mutate(
    return = (adjusted - lag(adjusted)) / lag(adjusted) * 100,
    log_return = log(adjusted / lag(adjusted)) * 100
  )

# Merge
analysis_data <- gme_returns %>%
  select(date, close, adjusted, return, log_return) %>%
  left_join(sentiment_daily, by = "date") %>%
  arrange(date) %>%
  mutate(
    # Lagged sentiment
    text_lag1 = lag(text_sentiment_weighted, 1),
    emoji_lag1 = lag(emoji_sentiment_weighted, 1),
    combined_lag1 = lag(combined_sentiment_weighted, 1),
    intensity_lag1 = lag(combined_intensity_weighted, 1),

    # Lagged returns
    return_lag1 = lag(return, 1)
  ) %>%
  filter(!is.na(return), !is.na(text_lag1))

cat("Analysis dataset has", nrow(analysis_data), "observations\n\n")

# Run regressions
model_text <- lm(return ~ text_lag1, data = analysis_data)
model_emoji <- lm(return ~ emoji_lag1, data = analysis_data)
model_combined <- lm(return ~ combined_lag1, data = analysis_data)
model_intensity <- lm(return ~ intensity_lag1, data = analysis_data)
model_both <- lm(return ~ text_lag1 + emoji_lag1, data = analysis_data)

# Compare R-squared
comparison <- tibble(
  Model = c("Text Only", "Emoji Only", "Combined",
            "Intensity-Adj", "Text + Emoji"),
  R_squared = c(
    summary(model_text)$r.squared,
    summary(model_emoji)$r.squared,
    summary(model_combined)$r.squared,
    summary(model_intensity)$r.squared,
    summary(model_both)$r.squared
  ),
  Adj_R_squared = c(
    summary(model_text)$adj.r.squared,
    summary(model_emoji)$adj.r.squared,
    summary(model_combined)$adj.r.squared,
    summary(model_intensity)$adj.r.squared,
    summary(model_both)$adj.r.squared
  )
)

cat("MODEL COMPARISON:\n")
print(comparison)
cat("\n")

# Detailed results for best model
best_model_idx <- which.max(comparison$R_squared)
cat("Best model:", comparison$Model[best_model_idx], "\n")
cat("R-squared:", round(comparison$R_squared[best_model_idx], 4), "\n\n")

# Regression table
modelsummary(
  list(
    "Text Only" = model_text,
    "Emoji Only" = model_emoji,
    "Combined" = model_combined,
    "Both Separate" = model_both
  ),
  stars = TRUE,
  gof_map = c("nobs", "r.squared", "adj.r.squared"),
  coef_rename = c(
    "text_lag1" = "Text Sentiment (t-1)",
    "emoji_lag1" = "Emoji Sentiment (t-1)",
    "combined_lag1" = "Combined Sentiment (t-1)"
  ),
  output = "output/tables/emoji_regression_results.html",
  title = "Regression Results: Text vs Emoji Sentiment"
)

cat("Regression table saved to output/tables/emoji_regression_results.html\n\n")

# Test if emojis add information beyond text
anova_result <- anova(model_text, model_both)
cat("F-test: Do emojis add information beyond text?\n")
print(anova_result)
cat("\n")

if (anova_result$`Pr(>F)`[2] < 0.05) {
  cat("✓ Emojis significantly improve prediction (p < 0.05)\n")
} else {
  cat("✗ Emojis do not significantly improve prediction (p >= 0.05)\n")
}


# SUMMARY STATISTICS ----------------------------------------------------------

cat("\n=== SUMMARY STATISTICS ===\n\n")

# Emoji usage stats
emoji_stats <- sentiment_combined %>%
  summarize(
    pct_comments_with_emoji = mean(n_emojis > 0) * 100,
    avg_emojis_per_comment = mean(n_emojis),
    max_emojis = max(n_emojis),
    pct_with_rockets = mean(has_rocket) * 100,
    pct_with_diamond_hands = mean(has_diamond_hands, na.rm = TRUE) * 100,
    avg_emoji_sentiment = mean(emoji_sentiment[n_emojis > 0])
  )

cat("EMOJI USAGE:\n")
cat(sprintf("  %.1f%% of comments contain at least one emoji\n",
            emoji_stats$pct_comments_with_emoji))
cat(sprintf("  Average emojis per comment: %.2f\n",
            emoji_stats$avg_emojis_per_comment))
cat(sprintf("  Max emojis in single comment: %d\n",
            emoji_stats$max_emojis))
cat(sprintf("  %.1f%% of comments have 🚀 (rocket)\n",
            emoji_stats$pct_with_rockets))
cat(sprintf("  %.1f%% of comments have 💎🙌 (diamond hands)\n",
            emoji_stats$pct_with_diamond_hands))
cat(sprintf("  Average emoji sentiment (emoji comments): %.2f\n\n",
            emoji_stats$avg_emoji_sentiment))

# Correlation between text and emoji sentiment
cor_test <- cor.test(sentiment_daily$text_sentiment,
                     sentiment_daily$emoji_sentiment)
cat("CORRELATION (Text vs Emoji Sentiment):\n")
cat(sprintf("  Correlation: %.3f\n", cor_test$estimate))
cat(sprintf("  P-value: %.4f\n", cor_test$p.value))
cat(sprintf("  Interpretation: %s\n\n",
            ifelse(abs(cor_test$estimate) < 0.3, "Weak correlation - emojis capture different signal",
                   ifelse(abs(cor_test$estimate) < 0.7, "Moderate correlation",
                          "Strong correlation - emojis reinforce text"))))


# FINAL SUMMARY ---------------------------------------------------------------

cat("=" , rep("=", 76), "=\n", sep = "")
cat("EMOJI SENTIMENT ANALYSIS COMPLETE\n")
cat("=" , rep("=", 76), "=\n", sep = "")

cat("\nKEY FINDINGS:\n")
cat(sprintf("1. %.1f%% of comments use emojis (vs %.1f%% without)\n",
            emoji_stats$pct_comments_with_emoji,
            100 - emoji_stats$pct_comments_with_emoji))

cat(sprintf("2. Most common emoji: %s (appears in %.1f%% of comments)\n",
            all_emojis$emojis[1],
            emoji_stats$pct_with_rockets))

cat(sprintf("3. Emoji-only model explains %.1f%% of return variation\n",
            comparison$R_squared[2] * 100))

cat(sprintf("4. Combined model explains %.1f%% (vs %.1f%% text-only)\n",
            comparison$R_squared[3] * 100,
            comparison$R_squared[1] * 100))

improvement <- (comparison$R_squared[3] - comparison$R_squared[1]) /
                comparison$R_squared[1] * 100

if (improvement > 0) {
  cat(sprintf("5. Including emojis improves prediction by %.1f%%\n", improvement))
} else {
  cat("5. Emojis do not improve prediction in this sample\n")
}

cat("\nOUTPUT FILES:\n")
cat("  - output/comment_level_sentiment_with_emojis.csv\n")
cat("  - output/daily_sentiment_with_emojis.csv\n")
cat("  - output/figures/text_vs_emoji_sentiment.png\n")
cat("  - output/figures/emoji_usage_over_time.png\n")
cat("  - output/figures/top_emojis.png\n")
cat("  - output/tables/emoji_regression_results.html\n")

cat("\nNEXT STEPS:\n")
cat("1. Review visualizations in output/figures/\n")
cat("2. Check regression results in output/tables/\n")
cat("3. Integrate emoji sentiment into main thesis analysis\n")
cat("4. Consider expanding emoji dictionary based on manual review\n")
cat("5. Validate emoji sentiment on sample of comments\n")

cat("\n" , rep("=", 78), "\n", sep = "")
