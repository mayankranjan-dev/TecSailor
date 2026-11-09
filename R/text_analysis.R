negation_words <- c("not", "no", "never", "without", "hardly", "neither", "nor")

clean_text <- function(x) {
  x |>
    str_to_lower() |>
    str_replace_all("[’`]", "'") |>
    str_replace_all("can't", "can not") |>
    str_replace_all("won't", "will not") |>
    str_replace_all("n't", " not") |>
    str_replace_all("https?://\\S+", " ") |>
    str_replace_all("[^a-z\\s]", " ") |>
    str_squish()
}

prepare_reviews <- function(data) {
  data |>
    filter(!is.na(review_text), review_text != "") |>
    distinct(review_id, .keep_all = TRUE) |>
    mutate(
      clean_text = clean_text(paste(title, review_text)),
      actual_sentiment = case_when(
        rating <= 2 ~ "negative",
        rating == 3 ~ "neutral",
        TRUE ~ "positive"
      ),
      actual_sentiment = factor(actual_sentiment, levels = c("negative", "neutral", "positive"))
    ) |>
    filter(str_count(clean_text, "\\S+") >= 3)
}

score_sentiment <- function(data) {
  lexicon <- get_sentiments("bing") |>
    mutate(value = ifelse(sentiment == "positive", 1, -1)) |>
    select(word, value)

  scores <- data |>
    select(review_id, clean_text) |>
    unnest_tokens(word, clean_text) |>
    group_by(review_id) |>
    mutate(previous = lag(word), before_previous = lag(word, 2)) |>
    ungroup() |>
    inner_join(lexicon, by = "word") |>
    mutate(value = ifelse(
      previous %in% negation_words | before_previous %in% negation_words,
      -value, value
    )) |>
    group_by(review_id) |>
    summarise(sentiment_score = sum(value), lexicon_hits = n(), .groups = "drop")

  data |>
    left_join(scores, by = "review_id") |>
    mutate(
      sentiment_score = coalesce(sentiment_score, 0),
      lexicon_hits = coalesce(lexicon_hits, 0L),
      predicted_sentiment = case_when(
        sentiment_score < 0 ~ "negative",
        sentiment_score > 0 ~ "positive",
        TRUE ~ "neutral"
      ),
      predicted_sentiment = factor(predicted_sentiment, levels = levels(actual_sentiment))
    )
}

classification_metrics <- function(actual, predicted) {
  classes <- c("negative", "neutral", "positive")
  actual <- factor(actual, levels = classes)
  predicted <- factor(predicted, levels = classes)

  by_class <- map_dfr(classes, function(label) {
    tp <- sum(actual == label & predicted == label)
    fp <- sum(actual != label & predicted == label)
    fn <- sum(actual == label & predicted != label)
    precision <- ifelse(tp + fp == 0, 0, tp / (tp + fp))
    recall <- ifelse(tp + fn == 0, 0, tp / (tp + fn))
    tibble(
      class = label,
      precision = precision,
      recall = recall,
      f1 = ifelse(precision + recall == 0, 0, 2 * precision * recall / (precision + recall))
    )
  })

  bind_rows(
    tibble(
      class = "overall",
      precision = mean(by_class$precision),
      recall = mean(by_class$recall),
      f1 = mean(by_class$f1)
    ),
    by_class
  ) |>
    mutate(
      accuracy = ifelse(class == "overall", mean(actual == predicted), NA_real_),
      balanced_accuracy = ifelse(class == "overall", mean(by_class$recall), NA_real_)
    )
}

aspect_dictionary <- tribble(
  ~word, ~aspect,
  "sound", "Sound", "audio", "Sound", "bass", "Sound", "music", "Sound",
  "battery", "Battery", "charge", "Battery", "charging", "Battery",
  "call", "Calling", "calling", "Calling", "mic", "Calling", "voice", "Calling",
  "connect", "Connectivity", "connection", "Connectivity", "bluetooth", "Connectivity",
  "fit", "Comfort", "comfort", "Comfort", "ear", "Comfort", "pain", "Comfort",
  "price", "Value", "money", "Value", "worth", "Value", "expensive", "Value",
  "quality", "Build quality", "build", "Build quality", "design", "Build quality",
  "delivery", "Delivery", "delivered", "Delivery", "package", "Delivery",
  "warranty", "Support", "service", "Support", "replace", "Support", "return", "Support"
)

analyse_aspects <- function(data) {
  data |>
    select(review_id, brand, actual_sentiment, clean_text) |>
    unnest_tokens(word, clean_text) |>
    inner_join(aspect_dictionary, by = "word") |>
    count(brand, aspect, actual_sentiment, name = "mentions")
}
