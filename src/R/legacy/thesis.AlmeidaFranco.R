getwd()
setwd("/Users/renatoventocilla")



library(tidyverse)
library(wesanderson)
library(dplyr)
library(haven)
library(foreign)
library(readr)
library(readxl)
library(purrr)
library(tibble)
library(quanteda)
library(readtext)
library(tidytext)
library(stringr)
library(tm)
library(NLP)
library(wordcloud)
library(RColorBrewer)
library(lubridate)
library(ggplot2)
library(scales)
library(syuzhet)
library(reshape2)
library(MetBrewer)
library(PNWColors)
library(hrbrthemes)
library(tidyquant)
library(zoo)
library(xts)
library(PerformanceAnalytics)
library(quantmod)

remotes::install_github("hrbrmstr/hrbrthemes")

                 
my_gamestop_scores <- read_excel("comments_13-31_Jan_withscore.xlsx")

my_gamestop_13jan <- read_excel("comments_13_Jan.xlsx")
my_gamestop_14jan <- read_excel("comments_14_Jan.xlsx")
my_gamestop_15jan <- read_excel("comments_15_Jan.xlsx")
my_gamestop_16jan <- read_excel("comments_16_Jan.xlsx")
my_gamestop_17jan <- read_excel("comments_17_Jan.xlsx")
my_gamestop_18jan <- read_excel("comments_18_Jan.xlsx")
my_gamestop_19jan <- read_excel("comments_19_Jan.xlsx")
my_gamestop_20jan <- read_excel("comments_20_Jan.xlsx")
my_gamestop_21jan <- read_excel("comments_21_Jan.xlsx")
my_gamestop_22jan <- read_excel("comments_22_Jan.xlsx")
my_gamestop_23jan <- read_excel("comments_23_Jan.xlsx")
my_gamestop_24jan <- read_excel("comments_24_Jan.xlsx")
my_gamestop_27jan <- read_excel("comments_27_Jan.xlsx")
my_gamestop_28jan <- read_excel("comments_28_Jan.xlsx")
my_gamestop_29jan <- read_excel("comments_29_Jan.xlsx")
my_gamestop_30jan <- read_excel("comments_30_Jan.xlsx")
my_gamestop_31jan <- read_excel("comments_31_Jan.xlsx")


my_gamestop_13jan <- my_gamestop_13jan %>%
select(body, date)

my_gamestop_14jan <- my_gamestop_14jan %>%
  select(body, date)

my_gamestop_15jan <- my_gamestop_15jan %>%
  select(body, date)

my_gamestop_16jan <- my_gamestop_16jan %>%
  select(body, date)

my_gamestop_17jan <- my_gamestop_17jan %>%
  select(body, date)

my_gamestop_18jan <- my_gamestop_18jan %>%
  select(body, date)

my_gamestop_19jan <- my_gamestop_19jan %>%
  select(body, date)

my_gamestop_20jan <- my_gamestop_20jan %>%
  select(body, date)

my_gamestop_21jan <- my_gamestop_21jan %>%
  select(body, date)

my_gamestop_22jan <- my_gamestop_22jan %>%
  select(body, date)

my_gamestop_23jan <- my_gamestop_23jan %>%
  select(body, date)

my_gamestop_24jan <- my_gamestop_24jan %>%
  select(body, date)

my_gamestop_27jan <- my_gamestop_27jan %>%
  select(body, date)

my_gamestop_28jan <- my_gamestop_28jan %>%
  select(body, date)

my_gamestop_29jan <- my_gamestop_29jan %>%
  select(body, date)

my_gamestop_30jan <- my_gamestop_30jan %>%
  select(body, date)

my_gamestop_31jan <- my_gamestop_31jan %>%
  select(body, date)

my_gamestop_scores <- my_gamestop_scores %>%
  select(body, date, score)


my_gamestop <- list(my_gamestop_13jan, my_gamestop_14jan, my_gamestop_15jan, my_gamestop_16jan, my_gamestop_17jan, my_gamestop_18jan,
                    my_gamestop_19jan, my_gamestop_20jan, my_gamestop_21jan, my_gamestop_22jan, my_gamestop_23jan, my_gamestop_24jan,
                    my_gamestop_27jan, my_gamestop_28jan, my_gamestop_29jan, my_gamestop_30jan, my_gamestop_31jan) %>%
  reduce(bind_rows, id = NULL)


view(my_gamestop)


# First of all, doing the Financial analysis plots

# Obtaining the stock prices period  of some of the meme stocks during January 2021

gme <- tq_get(c("GME", "DDS", "BBBY", "FIZZ", "NOK", "BB", "AMC"),
              get="stock.prices",
              from = "2021-01-01",
              to = "2021-02-01") 

# And their time period ranging since the beginning of 2020.

historic_gme <- tq_get(c("GME", "DDS", "BBBY", "FIZZ", "NOK", "BB", "AMC"), 
                       get="stock.prices",
                       from = "2020-01-01",
                       to = "2021-05-01") 

# Grouping both by the stock sybol                       

gme %>%
  group_by(symbol) 

historic_gme %>%
  group_by(symbol)


# Adjusted price of GME after paying off the dividends from 2020 to February 2021

historic_gme %>%
  filter(symbol == "GME") %>%
  ggplot(aes(x = date, y = adjusted)) +
  geom_line(color = palette_light()[[1]]) + 
  scale_y_log10() +
  geom_smooth(method = "lm") + 
  theme_tq()

# Obtaining the voluma as the total number of shares that are traded from the January 2020 to May 2021

historic_gme %>%
  filter(symbol == "GME") %>%
ggplot(aes(x = date, y = volume)) +
  geom_segment(aes(xend = date, yend = 0, color = volume)) + 
  geom_smooth(method = "loess", se = FALSE) +
  labs(title = "Volume Chart", 
       subtitle = "Charting Daily Volume", 
       y = "Volume", x = "") +
  theme_tq() +
  theme(legend.position = "none") 

view()

# Overview of the meme stocks from January 2020 to May 2021

historic_gme_plot <- ggplot(historic_gme, aes(x = date, y = close, group = symbol, color = symbol)) + geom_line(size = 1.5, alpha = 0.7) + geom_point(size = 0.7, alpha = 0.5) +
  labs(x = "Date", y = "Closing Price") + theme_bw() + scale_color_manual(values= met.brewer("Veronese", 10)) +
  theme(
    panel.border = element_blank(),
    axis.line = element_line(color = "grey"),
    axis.ticks = element_line(color = "grey"),
    axis.title.y = element_text(angle = 0)
  ) + facet_wrap(~ symbol, ncol = 2) + scale_x_date(date_breaks = "4 months", labels=date_format("%b %y")) +
  ggtitle("Overview of Meme Stocks from January 2020 to May 2021")

historic_gme_plot

ggsave("historic_gme_plot.png", device = "png")

# Chart analyzing the rise of GameStop

GME_plot <- ggplot(gme, aes(x = date, y = close, group = symbol, color = symbol)) + geom_line(size = 1.5, alpha = 0.7) + geom_point(size = 0.7, alpha = 0.5) +
  labs(x = "Date", y = "Closing Price") + theme_bw() + scale_color_manual(values= met.brewer("Veronese", 7)) +
  theme(
    panel.border = element_blank(),
    axis.line = element_line(color = "grey"),
    axis.ticks = element_line(color = "grey"),
    axis.title.y = element_text(angle = 0)
  ) + scale_x_date(date_breaks = "2 days", date_labels = "%b %d") + scale_y_continuous(breaks = seq(from = 0, to = 350, by = 50)) + ggtitle("The Rise of Gamestop during January 2021")

GME_plot

ggsave("GME_plot.png", device = "png", width = 30, height = 20, units = "cm")


# Transforming the body of texts into words

names(my_gamestop) <- c('text', 'date')


my_gamestop

unmy_gamestop <- my_gamestop %>%
  unnest_tokens(word, text)

data(stop_words)

nowords <- c("deleted", "removed")
lexicon <-  rep("custom", times = length(word))

mystopwords <- data.frame(nowords, lexicon)
names(mystopwords) <- c("nowords", "lexicon")

stop_words <- dplyr::bind_rows(stop_words, mystopwords)

antimy_gamestop <- unmy_gamestop %>%
  anti_join(stop_words)

view(antimy_gamestop)

# with highest scores

names(my_gamestop_scores) <- c('text', 'date', 'scores')

unmy_gamestop_scores <- my_gamestop_scores %>%
  unnest_tokens(word, text)

anti_scores <- unmy_gamestop_scores %>%
  anti_join(stop_words)

# thinking about sentiments

afinn <- get_sentiments("afinn")
get_sentiments("nrc")
bing <- get_sentiments("bing")

nrc_trust <- get_sentiments("nrc") %>% 
  filter(sentiment == "trust")

nrc_joy <- get_sentiments("nrc") %>% 
  filter(sentiment == "joy")

nrc_trust <- get_sentiments("nrc") %>% 
  filter(sentiment == "trust")

nrc_disgust <- get_sentiments("nrc") %>% 
  filter(sentiment == "disgust")

nrc_anticipation <- get_sentiments("nrc") %>% 
  filter(sentiment == "anticipation")

nrc_surprise <- get_sentiments("nrc") %>% 
  filter(sentiment == "surprise")

nrc_sadness <- get_sentiments("nrc") %>% 
  filter(sentiment == "sadness")

nrc_anger <- get_sentiments("nrc") %>% 
  filter(sentiment == "anger")

nrc_fear <- get_sentiments("nrc") %>% 
  filter(sentiment == "fear")

nrc_negative <- get_sentiments("nrc") %>% 
  filter(sentiment == "negative")

nrc_positive <- get_sentiments("nrc") %>% 
  filter(sentiment == "positive")

# Doing the first Sentiment Analysis

antimy_gamestop %>%
RedditFeelings <- get_nrc_sentiment(antimy_gamestop$word)

RedditFeelings2 <- get_nrc_sentiment(antimy_gamestop$word) %>%
  filter(!(sentiment %in% c("positive", "negative")))

RedditFeelings3 <- get_nrc_sentiment(antimy_gamestop$word) %>%
  filter((sentiment %in% c("positive", "negative")))

RedditFeelings <- data.frame(colSums(RedditFeelings))
names(RedditFeelings) <- "count"
RedditFeelings <- cbind("sentiment" = rownames(RedditFeelings), RedditFeelings)
rownames(RedditFeelings) <- NULL

RedditFeelings2 <- RedditFeelings %>%
  filter(!(sentiment %in% c("positive", "negative")))

RedditFeelings3 <- RedditFeelings %>%
  filter((sentiment %in% c("positive", "negative")))

RedditFeelings2 <- data.frame(colSums(RedditFeelings2))
names(RedditFeelings2) <- "count"
RedditFeelings2 <- cbind("sentiment" = rownames(RedditFeelings2), RedditFeelings2)
rownames(RedditFeelings2) <- NULL

RedditFeelings3 <- data.frame(colSums(RedditFeelings3))
names(RedditFeelings3) <- "count"
RedditFeelings3 <- cbind("sentiment" = rownames(RedditFeelings3), RedditFeelings3)
rownames(RedditFeelings3) <- NULL

# Anti my game stop scores


RedditFeelings4 <- get_nrc_sentiment(anti_scores$word)

RedditFeelings4 <- data.frame(colSums(RedditFeelings4))
names(RedditFeelings4) <- "count"
RedditFeelings4 <- cbind("sentiment" = rownames(RedditFeelings4), RedditFeelings4)
rownames(RedditFeelings4) <- NULL

# Doing the plots

C <- ggplot(data = RedditFeelings, aes(x = sentiment, y = count)) + geom_bar(aes(fill = sentiment), stat = "identity") + theme(legend.position = "none") + xlab("Sentiment") + ylab("Total Count") + ggtitle("Total Sentiment Score for the Reddit Comments") + theme_minimal() + scale_fill_manual(values = pal2)

D <- ggplot(data = RedditFeelings2, aes(x = sentiment, y = count)) + geom_bar(aes(fill = sentiment), stat = "identity") + theme(legend.position = "none") + xlab("Sentiment") + ylab("Total Count") + ggtitle("Total Sentiment Score for the Reddit Comments") + theme_minimal() + scale_fill_manual(values = pal2)

E <- ggplot(data = RedditFeelings3, aes(x = sentiment, y = count)) + geom_bar(aes(fill = sentiment), stat = "identity") + theme(legend.position = "none") + xlab("Sentiment") + ylab("Total Count") + ggtitle("Positive or Negative Sentiment Score for the Reddit Comments") + theme_minimal() + scale_fill_manual(values = pal3)

G <- ggplot(data = RedditFeelings4, aes(x = sentiment, y = count)) + geom_bar(aes(fill = sentiment), stat = "identity") + theme(legend.position = "none") + xlab("Sentiment") + ylab("Total Count") + ggtitle("Total Sentiment Score for the Reddit Comments") + theme_ipsum() + scale_fill_manual(values = met.brewer("Degas", 10))


C

D

E

G


# Plot about trust

trust_GME <- antimy_gamestop %>%
  group_by(date) %>%
  inner_join(nrc_trust) %>%
  count(word, sort = TRUE)


emotionplot_trust <- trust_GME %>%
  select(date, n) %>%
  group_by(date) %>%
  summarize(sum_n = sum(n))

#now positive
positive_GME <- antimy_gamestop %>%
  group_by(date) %>%
  inner_join(nrc_positive) %>%
  count(word, sort = TRUE)


emotionplot_positive <- positive_GME %>%
  select(date, n) %>%
  group_by(date) %>%
  summarize(sum_n = sum(n))

# Negative

negative_GME <- antimy_gamestop %>%
  group_by(date) %>%
  inner_join(nrc_negative) %>%
  count(word, sort = TRUE)


emotionplot_negative <- negative_GME %>%
  select(date, n) %>%
  group_by(date) %>%
  summarize(sum_n = sum(n))

# Other feelings

anger_GME <- antimy_gamestop %>%
  group_by(date) %>%
  inner_join(nrc_anger) %>%
  count(word, sort = TRUE)

emotionplot_anger <- anger_GME %>%
  select(date, n) %>%
  group_by(date) %>%
  summarize(sum_n = sum(n))


anticipation_GME <- antimy_gamestop %>%
  group_by(date) %>%
  inner_join(nrc_anticipation) %>%
  count(word, sort = TRUE)

emotionplot_anticipation <- anticipation_GME %>%
  select(date, n) %>%
  group_by(date) %>%
  summarize(sum_n = sum(n))


disgust_GME <- antimy_gamestop %>%
  group_by(date) %>%
  inner_join(nrc_disgust) %>%
  count(word, sort = TRUE)

emotionplot_disgust <- disgust_GME %>%
  select(date, n) %>%
  group_by(date) %>%
  summarize(sum_n = sum(n))


joy_GME <- antimy_gamestop %>%
  group_by(date) %>%
  inner_join(nrc_joy) %>%
  count(word, sort = TRUE)

emotionplot_joy <- joy_GME %>%
  select(date, n) %>%
  group_by(date) %>%
  summarize(sum_n = sum(n))


sadness_GME <- antimy_gamestop %>%
  group_by(date) %>%
  inner_join(nrc_sadness) %>%
  count(word, sort = TRUE)

emotionplot_sadness <- sadness_GME %>%
  select(date, n) %>%
  group_by(date) %>%
  summarize(sum_n = sum(n))


surprise_GME <- antimy_gamestop %>%
  group_by(date) %>%
  inner_join(nrc_surprise) %>%
  count(word, sort = TRUE)

emotionplot_surprise <- surprise_GME %>%
  select(date, n) %>%
  group_by(date) %>%
  summarize(sum_n = sum(n))

fear_GME <- antimy_gamestop %>%
  group_by(date) %>%
  inner_join(nrc_fear) %>%
  count(word, sort = TRUE)

emotionplot_fear <- fear_GME %>%
  select(date, n) %>%
  group_by(date) %>%
  summarize(sum_n = sum(n))

# Using the BING dictionary

bing_positive <- bing %>% 
  filter(sentiment == "positive")

bing_negative <- bing %>% 
  filter(sentiment == "negative")


posibing_GME <- antimy_gamestop %>%
  group_by(date) %>%
  inner_join(bing_positive) %>%
  count(word, sort = TRUE)


emotionplotbing_positive <- posibing_GME %>%
  select(date, n) %>%
  group_by(date) %>%
  summarize(sum_n = sum(n))


negatbing_GME <- antimy_gamestop %>%
  group_by(date) %>%
  inner_join(bing_negative) %>%
  count(word, sort = TRUE)

emotionplotbing_negative <- negatbing_GME %>%
  select(date, n) %>%
  group_by(date) %>%
  summarize(sum_n = sum(n))

emotionplotbing_negative

emotionplotbing_positive$emotion <- "positive"
emotionplotbing_negative$emotion <- "negative"


emotionplot_bing <- bind_rows(emotionplotbing_positive, emotionplotbing_negative)

view(emotionplot_bing)

ggplot(emotionplot_bing, aes(x = date, y = sum_n, color = emotion)) + geom_line() + theme_minimal() + geom_point() + scale_color_manual(values = met.brewer("Veronese", 2))


perbing <- emotionplot_bing %>%
  group_by(date) %>%
  mutate(percent =  sum_n/sum(sum_n) * 100)

ggplot(perbing, aes(x = date, y = percent, color = emotion)) + geom_line() + theme_minimal() + geom_point() + scale_color_manual(values = met.brewer("Veronese", 2))


# Doing the ggplot

emotionplot_positive$emotion <- "positive"
emotionplot_trust$emotion <- "trust"
emotionplot_negative$emotion <- "negative"

emotionplot_anger$emotion <- "anger"
emotionplot_anticipation$emotion <- "anticipation"
emotionplot_disgust$emotion <- "disgust"
emotionplot_sadness$emotion <- "sadness"
emotionplot_surprise$emotion <- "surprise"
emotionplot_fear$emotion <- "fear"

emotionplot_posnegall <- bind_rows(emotionplot_positive, emotionplot_negative)
emotionplot_all <- bind_rows(emotionplot_trust, emotionplot_anger, emotionplot_anticipation, emotionplot_disgust, emotionplot_sadness, emotionplot_surprise, emotionplot_fear)

view(emotionplot_all)

per <- emotionplot_posnegall %>%
  group_by(date) %>%
  mutate(percent =  sum_n/sum(sum_n) * 100)

percen <- emotionplot_all %>%
  group_by(date) %>%
  mutate(percent =  sum_n/sum(sum_n) * 100)


emotionplot_all$after <- ifelse(emotionplot_all$date > (as.Date("2021-01-24")), 1, 0)
 
ggplot(percen, aes(x = date, y = percent, color = emotion)) + geom_line(size = 1.2, alpha = 0.7) + theme_ipsum() + geom_point(size = 1.5, alpha = 0.5) + scale_color_manual(values = met.brewer("Veronese", 10)) + scale_x_date(date_breaks = "2 days", date_labels = "%b %d")

ggplot(per, aes(x = date, y = percent, color = emotion)) +  geom_line(size = 1.5, alpha = 0.7) + theme_minimal() + geom_point() + scale_color_manual(values = met.brewer("Veronese", 6)) + scale_x_date(date_breaks = "2 days", date_labels = "%b %d")


ggplot(emotionplot_posnegall, aes(x = date, y = sum_n, color = emotion)) +  geom_line(size = 1.5, alpha = 0.7) + theme_minimal() + geom_point() + scale_color_manual(values = met.brewer("Veronese", 6))


per$date <- as.Date(per$date)
percen$date <- as.Date(percen$date)

sum(trust_GME$n)


# Number of words used mostly 

bing_gamestop <- antimy_gamestop %>%
  inner_join(get_sentiments("bing")) %>%
  count(word, sentiment, sort = TRUE) %>%
  ungroup()

pal2 <- met.brewer("Wissing", n = 2)

pal3 <- met.brewer("Wissing", n = 3)

E <- bing_gamestop %>%
  group_by(sentiment) %>%
  slice_max(n, n = 30) %>% 
  ungroup() %>%
  mutate(word = reorder(word, n)) %>%
  ggplot(aes(n, word, fill = sentiment)) +
  geom_col(show.legend = FALSE) +
  scale_fill_manual(values = pal2) +
  facet_wrap(~sentiment, scales = "free_y") +
  labs(x = "Contribution to sentiment",
       y = NULL) + theme_ipsum()
E


afinn_gamestop <- antimy_gamestop %>%
  inner_join(get_sentiments("afinn"), by = "word") %>%
  count(word, sentiment, sort = TRUE) %>%
  ungroup()

pal2 <- met.brewer("Wissing", n = 7)

E <- bing_gamestop %>%
  group_by(sentiment) %>%
  slice_max(n, n = 30) %>% 
  ungroup() %>%
  mutate(word = reorder(word, n)) %>%
  ggplot(aes(n, word, fill = sentiment)) +
  geom_col(show.legend = FALSE) +
  scale_fill_manual(values = pal2) +
  facet_wrap(~sentiment, scales = "free_y") +
  labs(x = "Contribution to sentiment",
       y = NULL) + theme_minimal()
E

trust_GME %>%
filter(n == "hold")

