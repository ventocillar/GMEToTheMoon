# ==============================================================================
# 02_preprocess_text.R
# Chunked text preprocessing: processes comments month-by-month to stay
# within 16 GB RAM. Extracts emojis BEFORE tokenization, then tokenizes.
# Outputs: daily token counts and emoji counts (not the full token dataframes)
# ==============================================================================

message("=== 02: Preprocessing text (chunked by month) ===")

# --- Emoji regex pattern ------------------------------------------------------

emoji_pattern <- paste0(

  "[",
  "\U0001F600-\U0001F64F",
  "\U0001F300-\U0001F5FF",
  "\U0001F680-\U0001F6FF",
  "\U0001F900-\U0001F9FF",
  "\U0001FA00-\U0001FA6F",
  "\U0001FA70-\U0001FAFF",
  "\U00002702-\U000027B0",
  "\U0000FE00-\U0000FE0F",
  "\U0000200D",
  "\U000000A9\U000000AE",
  "\U00002122-\U00002199",
  "\U00002600-\U000026FF",
  "\U00002300-\U000023FF",
  "]+"
)

# --- Stop words ---------------------------------------------------------------

data("stop_words", package = "tidytext")

reddit_stop_words <- tibble(
  word = c("deleted", "removed", "http", "https", "www", "amp",
           "gt", "lt", "edit", "nbsp", "reddit", "subreddit",
           "comment", "post", "thread", "upvote", "downvote",
           "op", "tldr", "imo", "imho", "lol", "lmao", "lmfao",
           "gonna", "gotta", "wanna", "dont", "doesnt", "didnt",
           "im", "ive", "id", "youre", "hes", "shes", "theyre",
           "thats", "whats", "theres", "isnt", "arent", "wasnt",
           "cant", "wont", "wouldnt", "shouldnt", "couldnt"),
  lexicon = "custom"
)

all_stop_words <- bind_rows(stop_words, reddit_stop_words)

# --- Define monthly chunks ----------------------------------------------------

chunk_months <- seq(
  floor_date(STUDY_START, "month"),
  floor_date(STUDY_END, "month"),
  by = "month"
)

# --- Process each month -------------------------------------------------------

# Accumulators for daily results
all_tokens_daily <- list()
all_emojis_daily <- list()
all_emoji_raw    <- list()  # Keep emoji-level data (small enough)
total_tokens_raw <- 0
total_tokens_clean <- 0
total_emojis <- 0

conn <- get_db_connection()

for (i in seq_along(chunk_months)) {
  month_start <- chunk_months[i]
  month_end   <- ceiling_date(month_start, "month") - days(1)
  month_end   <- min(month_end, STUDY_END)
  month_label <- format(month_start, "%Y-%m")

  message(sprintf("  Processing %s ...", month_label))

  # --- Load chunk from SQLite -----------------------------------------------
  chunk <- dbGetQuery(conn, sprintf(
    "SELECT comment_id, body, author, score, date
     FROM comments
     WHERE date >= '%s' AND date <= '%s'",
    month_start, month_end
  ))

  if (nrow(chunk) == 0) next

  chunk <- chunk %>% mutate(date = as.Date(date))
  message(sprintf("    Loaded %s comments", format(nrow(chunk), big.mark = ",")))

  # --- Emoji extraction (BEFORE tokenization) -------------------------------
  chunk_emojis <- chunk %>%
    dplyr::select(comment_id, body, date, score) %>%
    mutate(emojis = stringi::stri_extract_all_regex(body, emoji_pattern)) %>%
    filter(!sapply(emojis, function(x) all(is.na(x)))) %>%
    unnest(emojis) %>%
    mutate(emoji_chars = strsplit(emojis, "")) %>%
    unnest(emoji_chars) %>%
    dplyr::select(comment_id, date, score, emoji = emoji_chars)

  total_emojis <- total_emojis + nrow(chunk_emojis)

  # Store emoji raw data (relatively small)
  all_emoji_raw[[i]] <- chunk_emojis

  # Daily emoji summary
  all_emojis_daily[[i]] <- chunk_emojis %>%
    count(date, emoji, name = "n") %>%
    mutate(month = month_label)

  rm(chunk_emojis)

  # --- Text cleaning + tokenization -----------------------------------------
  chunk_text <- chunk %>%
    dplyr::select(comment_id, text = body, date, score) %>%
    mutate(
      text = str_replace_all(text, "https?://\\S+", ""),
      text = str_replace_all(text, "\\[.*?\\]\\(.*?\\)", ""),
      text = str_replace_all(text, "[\\r\\n]+", " "),
      text = str_replace_all(text, "&amp;", "and"),
      text = str_replace_all(text, "&gt;|&lt;", ""),
      text = str_replace_all(text, "\\$", "")
    )

  rm(chunk)  # Free raw comments
  gc()

  chunk_tokens <- chunk_text %>%
    unnest_tokens(word, text)

  rm(chunk_text)
  gc()

  total_tokens_raw <- total_tokens_raw + nrow(chunk_tokens)

  chunk_tokens <- chunk_tokens %>%
    anti_join(all_stop_words, by = "word") %>%
    filter(!str_detect(word, "^\\d+$"), nchar(word) > 1)

  total_tokens_clean <- total_tokens_clean + nrow(chunk_tokens)

  # --- Store tokens with date+score for sentiment computation ---------------
  # We keep this in memory temporarily for sentiment analysis in 03
  all_tokens_daily[[i]] <- chunk_tokens

  message(sprintf("    Tokens: %s clean | Emojis: %s",
                  format(nrow(chunk_tokens), big.mark = ","),
                  format(nrow(all_emoji_raw[[i]]), big.mark = ",")))

  rm(chunk_tokens)
  gc()
}

dbDisconnect(conn)

# --- Combine emoji data (small enough to hold) --------------------------------

emoji_extracted <- bind_rows(all_emoji_raw)
rm(all_emoji_raw)

emoji_freq <- emoji_extracted %>%
  count(emoji, sort = TRUE) %>%
  head(30)

# --- Summary ------------------------------------------------------------------

message(sprintf("\n  Total: %s raw -> %s clean tokens (%.1f%% removed)",
                format(total_tokens_raw, big.mark = ","),
                format(total_tokens_clean, big.mark = ","),
                (1 - total_tokens_clean / total_tokens_raw) * 100))
message(sprintf("  Total emojis: %s (%d unique)",
                format(total_emojis, big.mark = ","),
                n_distinct(emoji_extracted$emoji)))
message(sprintf("  Top 5 emojis: %s",
                paste(emoji_freq$emoji[1:min(5, nrow(emoji_freq))], collapse = " ")))
message("Preprocessing complete.\n")
