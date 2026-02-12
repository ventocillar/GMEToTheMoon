# ==============================================================================
# 04_financial_data.R
# Fetch stock price data for meme and control stocks
# Store in SQLite for reproducibility
# ==============================================================================

message("=== 04: Fetching financial data ===")

stock_start <- as.Date(cfg$stock_period$start)
stock_end   <- as.Date(cfg$stock_period$end)

# --- Fetch stock prices -------------------------------------------------------

message("  Downloading stock prices for: ", paste(ALL_STOCKS, collapse = ", "))

stock_prices <- tq_get(
  ALL_STOCKS,
  get = "stock.prices",
  from = stock_start,
  to = stock_end
)

# --- Compute returns ----------------------------------------------------------

stock_prices <- stock_prices %>%
  group_by(symbol) %>%
  arrange(date) %>%
  mutate(
    daily_return = (adjusted / lag(adjusted)) - 1,
    log_return   = log(adjusted / lag(adjusted)),
    abnormal_volume = volume / mean(volume[date < as.Date("2021-01-01")], na.rm = TRUE)
  ) %>%
  ungroup()

message(sprintf("  Downloaded %s rows for %d stocks (%s to %s)",
                format(nrow(stock_prices), big.mark = ","),
                n_distinct(stock_prices$symbol),
                min(stock_prices$date), max(stock_prices$date)))

# --- Store in SQLite ----------------------------------------------------------

conn <- get_db_connection()

# Clear existing and write fresh
dbExecute(conn, "DELETE FROM stock_prices")

stock_to_db <- stock_prices %>%
  select(symbol, date, open, high, low, close, volume, adjusted,
         daily_return, log_return)

dbWriteTable(conn, "stock_prices", stock_to_db, append = TRUE, row.names = FALSE)

message(sprintf("  Stored %s rows in stock_prices table",
                format(nrow(stock_to_db), big.mark = ",")))

dbDisconnect(conn)

# --- Separate meme vs control -------------------------------------------------

meme_prices <- stock_prices %>% filter(symbol %in% MEME_STOCKS)
ctrl_prices <- stock_prices %>% filter(symbol %in% CTRL_STOCKS)

# --- GME specific data --------------------------------------------------------

gme_prices <- stock_prices %>%
  filter(symbol == "GME") %>%
  select(date, gme_return = daily_return, gme_log_return = log_return,
         gme_close = adjusted, gme_volume = volume,
         gme_abnormal_volume = abnormal_volume)

message("Financial data complete.\n")
