# ==============================================================================
# helpers/sentiment_functions.R
# Core parameterized sentiment computation functions
# Replaces ~200 lines of copy-pasted sentiment code from the original script
# ==============================================================================

#' Compute sentiment scores using a specified lexicon
#'
#' @param tokens_df Data frame with columns: word, date, score (comment score)
#' @param lexicon_name One of: "nrc", "bing", "afinn", "loughran", "wsb_custom"
#' @param weight_by_score Logical; weight sentiment by log(comment_score + 1)
#' @return Data frame with daily sentiment aggregates
compute_sentiment_by_lexicon <- function(tokens_df, lexicon_name,
                                         weight_by_score = FALSE) {

  # Load the appropriate lexicon
  lexicon_df <- switch(
    lexicon_name,
    "nrc" = {
      tidytext::get_sentiments("nrc")
    },
    "bing" = {
      tidytext::get_sentiments("bing") %>%
        mutate(value = ifelse(sentiment == "positive", 1, -1))
    },
    "afinn" = {
      tidytext::get_sentiments("afinn")
    },
    "loughran" = {
      tidytext::get_sentiments("loughran")
    },
    "wsb_custom" = {
      wsb_path <- here::here("data", "lexicons", "wsb_lexicon.csv")
      if (!file.exists(wsb_path)) stop("WSB lexicon not found at: ", wsb_path)
      read_csv(wsb_path, show_col_types = FALSE)
    },
    stop("Unknown lexicon: ", lexicon_name)
  )

  # --- NRC: categorical emotions ---
  if (lexicon_name == "nrc") {
    result <- tokens_df %>%
      inner_join(lexicon_df, by = "word") %>%
      group_by(date, sentiment) %>%
      summarize(
        raw_count = n(),
        weighted_count = if (weight_by_score) sum(log(score + 2)) else n(),
        .groups = "drop"
      ) %>%
      rename(emotion = sentiment) %>%
      mutate(lexicon = "nrc")
    return(result)
  }

  # --- BING: pos/neg categories ---
  if (lexicon_name == "bing") {
    result <- tokens_df %>%
      inner_join(lexicon_df, by = "word") %>%
      group_by(date, sentiment) %>%
      summarize(
        raw_count = n(),
        weighted_count = if (weight_by_score) sum(value * log(score + 2)) else sum(value),
        .groups = "drop"
      ) %>%
      rename(emotion = sentiment) %>%
      mutate(lexicon = "bing")
    return(result)
  }

  # --- AFINN: numeric values ---
  if (lexicon_name == "afinn") {
    result <- tokens_df %>%
      inner_join(lexicon_df, by = "word") %>%
      group_by(date) %>%
      summarize(
        raw_count = n(),
        weighted_count = if (weight_by_score) {
          sum(value * log(score + 2))
        } else {
          sum(value)
        },
        mean_sentiment = mean(value),
        .groups = "drop"
      ) %>%
      mutate(emotion = "score", lexicon = "afinn")
    return(result)
  }

  # --- Loughran-McDonald: financial sentiment categories ---
  if (lexicon_name == "loughran") {
    result <- tokens_df %>%
      inner_join(lexicon_df, by = "word") %>%
      group_by(date, sentiment) %>%
      summarize(
        raw_count = n(),
        weighted_count = if (weight_by_score) sum(log(score + 2)) else n(),
        .groups = "drop"
      ) %>%
      rename(emotion = sentiment) %>%
      mutate(lexicon = "loughran")
    return(result)
  }

  # --- WSB Custom: numeric values ---
  if (lexicon_name == "wsb_custom") {
    result <- tokens_df %>%
      inner_join(lexicon_df, by = "word") %>%
      group_by(date) %>%
      summarize(
        raw_count = n(),
        weighted_count = if (weight_by_score) {
          sum(value * log(score + 2))
        } else {
          sum(value)
        },
        mean_sentiment = mean(value),
        bullish_count = sum(value > 0),
        bearish_count = sum(value < 0),
        .groups = "drop"
      ) %>%
      mutate(emotion = "score", lexicon = "wsb_custom")
    return(result)
  }
}


#' Compute emoji sentiment scores
#'
#' @param emoji_df Data frame with columns: emoji, date, score (comment score)
#' @param weight_by_score Logical; weight by log(comment_score + 1)
#' @return Data frame with daily emoji sentiment
compute_emoji_sentiment <- function(emoji_df, weight_by_score = FALSE) {

  emoji_lexicon_path <- here::here("data", "lexicons", "wsb_emoji_lexicon.csv")
  if (!file.exists(emoji_lexicon_path)) {
    stop("Emoji lexicon not found at: ", emoji_lexicon_path)
  }
  emoji_lex <- read_csv(emoji_lexicon_path, show_col_types = FALSE)

  result <- emoji_df %>%
    inner_join(emoji_lex, by = "emoji") %>%
    group_by(date) %>%
    summarize(
      raw_count = n(),
      weighted_count = if (weight_by_score) {
        sum(value * log(score + 2))
      } else {
        sum(value)
      },
      mean_sentiment = mean(value),
      bullish_emoji = sum(value > 0),
      bearish_emoji = sum(value < 0),
      .groups = "drop"
    ) %>%
    mutate(emotion = "score", lexicon = "emoji")

  return(result)
}


#' Run all lexicons and combine results
#'
#' @param tokens_df Tokenized words with date and score
#' @param emoji_df Extracted emojis with date and score
#' @param weight_by_score Logical
#' @return Combined data frame of all sentiment results
compute_all_sentiments <- function(tokens_df, emoji_df = NULL,
                                    weight_by_score = FALSE) {

  lexicons <- c("nrc", "bing", "afinn", "loughran", "wsb_custom")

  results <- map_dfr(lexicons, function(lex) {
    tryCatch(
      compute_sentiment_by_lexicon(tokens_df, lex, weight_by_score),
      error = function(e) {
        warning("Error with lexicon '", lex, "': ", e$message)
        tibble()
      }
    )
  })

  if (!is.null(emoji_df) && nrow(emoji_df) > 0) {
    emoji_result <- tryCatch(
      compute_emoji_sentiment(emoji_df, weight_by_score),
      error = function(e) {
        warning("Error with emoji sentiment: ", e$message)
        tibble()
      }
    )
    results <- bind_rows(results, emoji_result)
  }

  return(results)
}


#' Normalize sentiment counts by daily comment volume
#'
#' @param sentiment_df Output from compute_all_sentiments
#' @param daily_counts Data frame with date and n_comments
#' @return Sentiment data with normalized column
normalize_sentiment <- function(sentiment_df, daily_counts) {
  counts <- daily_counts %>% select(date, n_comments)
  sentiment_df %>%
    left_join(counts, by = "date") %>%
    mutate(normalized = ifelse(n_comments > 0, raw_count / n_comments, 0)) %>%
    select(-n_comments)
}
