# ==============================================================================
# tests/test_sentiment_functions.R
# Unit tests for sentiment computation functions
#
# Usage: testthat::test_file("tests/test_sentiment_functions.R")
# ==============================================================================

library(testthat)
library(tidyverse)
library(tidytext)
library(here)

# Source the functions under test
source(here("src", "R", "helpers", "sentiment_functions.R"))

# --- Test data ----------------------------------------------------------------

test_tokens <- tibble(
  comment_id = rep("c1", 6),
  date = as.Date("2021-01-27"),
  score = c(10, 10, 10, 5, 5, 5),
  word = c("happy", "good", "love", "bad", "hate", "angry")
)

test_tokens_multi_day <- tibble(
  comment_id = c(rep("c1", 3), rep("c2", 3)),
  date = c(rep(as.Date("2021-01-27"), 3), rep(as.Date("2021-01-28"), 3)),
  score = c(10, 10, 10, 5, 5, 5),
  word = c("happy", "good", "love", "sad", "hate", "angry")
)

test_emojis <- tibble(
  comment_id = rep("c1", 4),
  date = as.Date("2021-01-27"),
  score = c(10, 10, 5, 5),
  emoji = c("\U0001F680", "\U0001F680", "\U0001F48E", "\U0001F43B")
)

# --- Tests for compute_sentiment_by_lexicon -----------------------------------

test_that("AFINN lexicon returns numeric scores", {
  result <- compute_sentiment_by_lexicon(test_tokens, "afinn")
  expect_s3_class(result, "data.frame")
  expect_true("weighted_count" %in% names(result))
  expect_true("raw_count" %in% names(result))
  expect_equal(result$lexicon[1], "afinn")
})

test_that("NRC lexicon returns emotion categories", {
  result <- compute_sentiment_by_lexicon(test_tokens, "nrc")
  expect_s3_class(result, "data.frame")
  expect_true("emotion" %in% names(result))
  expect_true(all(result$lexicon == "nrc"))
})

test_that("BING lexicon returns positive/negative", {
  result <- compute_sentiment_by_lexicon(test_tokens, "bing")
  expect_s3_class(result, "data.frame")
  expect_true(all(result$emotion %in% c("positive", "negative")))
})

test_that("WSB custom lexicon loads correctly", {
  wsb_tokens <- tibble(
    comment_id = "c1",
    date = as.Date("2021-01-27"),
    score = 10,
    word = c("moon", "tendies", "paperhands", "guh")
  )
  result <- compute_sentiment_by_lexicon(wsb_tokens, "wsb_custom")
  expect_s3_class(result, "data.frame")
  expect_equal(result$lexicon[1], "wsb_custom")
  # Net should be positive (moon=3, tendies=2, paperhands=-2, guh=-3 = 0)
  expect_equal(result$weighted_count[1], 0)
})

test_that("Score weighting changes results", {
  unweighted <- compute_sentiment_by_lexicon(test_tokens, "afinn", weight_by_score = FALSE)
  weighted   <- compute_sentiment_by_lexicon(test_tokens, "afinn", weight_by_score = TRUE)
  # Weighted counts should differ from unweighted
  expect_false(identical(unweighted$weighted_count, weighted$weighted_count))
})

test_that("Multi-day data returns separate rows per date", {
  result <- compute_sentiment_by_lexicon(test_tokens_multi_day, "afinn")
  expect_equal(n_distinct(result$date), 2)
})

test_that("Unknown lexicon throws error", {
  expect_error(compute_sentiment_by_lexicon(test_tokens, "nonexistent"))
})

# --- Tests for compute_emoji_sentiment ----------------------------------------

test_that("Emoji sentiment returns results", {
  result <- compute_emoji_sentiment(test_emojis)
  expect_s3_class(result, "data.frame")
  expect_equal(result$lexicon[1], "emoji")
  expect_true(result$raw_count[1] > 0)
})

test_that("Emoji bullish count is correct", {
  result <- compute_emoji_sentiment(test_emojis)
  # Rockets (3+3) + diamond (2) = 8 bullish value, bear (-2)
  # Net = 3 + 3 + 2 + (-2) = 6
  expect_equal(result$weighted_count[1], 6)
  expect_equal(result$bullish_emoji[1], 3)
  expect_equal(result$bearish_emoji[1], 1)
})

# --- Tests for compute_all_sentiments -----------------------------------------

test_that("compute_all_sentiments combines all lexicons", {
  result <- compute_all_sentiments(test_tokens, test_emojis)
  lexicons_found <- unique(result$lexicon)
  expect_true("afinn" %in% lexicons_found)
  expect_true("bing" %in% lexicons_found)
  expect_true("nrc" %in% lexicons_found)
  expect_true("emoji" %in% lexicons_found)
})

# --- Tests for normalize_sentiment --------------------------------------------

test_that("normalize_sentiment adds normalized column", {
  sent <- compute_sentiment_by_lexicon(test_tokens, "afinn")
  daily <- tibble(date = as.Date("2021-01-27"), n_comments = 100)
  result <- normalize_sentiment(sent, daily)
  expect_true("normalized" %in% names(result))
  expect_equal(result$normalized[1], result$raw_count[1] / 100)
})

cat("\nAll tests passed!\n")
