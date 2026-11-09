forecast_accuracy <- function(actual, predicted, model, brand) {
  tibble(
    brand = brand,
    model = model,
    MAE = mean(abs(actual - predicted)),
    RMSE = sqrt(mean((actual - predicted)^2)),
    WAPE = sum(abs(actual - predicted)) / sum(abs(actual))
  )
}

fit_one_model <- function(y, model_name) {
  if (model_name == "Seasonal naive") return(snaive(y))
  if (model_name == "STL + ETS") return(stlm(y, s.window = "periodic", method = "ets"))
  auto.arima(y, seasonal = TRUE, stepwise = TRUE, approximation = FALSE)
}

evaluate_brand <- function(data, holdout = 26) {
  data <- arrange(data, date)
  y <- ts(data$interest, frequency = 52)
  train <- head(y, length(y) - holdout)
  test <- tail(y, holdout)
  names <- c("Seasonal naive", "STL + ETS", "ARIMA")

  map_dfr(names, function(name) {
    fit <- fit_one_model(train, name)
    prediction <- as.numeric(forecast(fit, h = holdout)$mean)
    forecast_accuracy(test, prediction, name, data$brand[1])
  })
}

build_forecast <- function(data, model_name, weeks = 52) {
  data <- arrange(data, date)
  y <- ts(data$interest, frequency = 52)
  fit <- fit_one_model(y, model_name)
  result <- forecast(fit, h = weeks, level = c(80, 95))
  tibble(
    date = seq(max(data$date) + 7, by = "week", length.out = weeks),
    brand = data$brand[1],
    model = model_name,
    forecast = as.numeric(result$mean),
    lower_80 = as.numeric(result$lower[, 1]),
    upper_80 = as.numeric(result$upper[, 1]),
    lower_95 = as.numeric(result$lower[, 2]),
    upper_95 = as.numeric(result$upper[, 2])
  ) |>
    mutate(across(c(forecast, lower_80, lower_95), ~ pmax(.x, 0)))
}

festival_calendar <- tribble(
  ~festival, ~date,
  "Republic Day", as.Date("2022-01-26"), "Independence Day", as.Date("2022-08-15"), "Diwali", as.Date("2022-10-24"),
  "Republic Day", as.Date("2023-01-26"), "Independence Day", as.Date("2023-08-15"), "Diwali", as.Date("2023-11-12"),
  "Republic Day", as.Date("2024-01-26"), "Independence Day", as.Date("2024-08-15"), "Diwali", as.Date("2024-11-01"),
  "Republic Day", as.Date("2025-01-26"), "Independence Day", as.Date("2025-08-15"), "Diwali", as.Date("2025-10-20"),
  "Republic Day", as.Date("2026-01-26"), "Independence Day", as.Date("2026-08-15"), "Diwali", as.Date("2026-11-08"),
  "Republic Day", as.Date("2027-01-26"), "Independence Day", as.Date("2027-08-15"), "Diwali", as.Date("2027-10-29")
)

festival_for_week <- function(dates) {
  map_chr(dates, function(day) {
    hit <- festival_calendar |>
      filter(date >= day, date <= day + 21) |>
      slice_min(date, n = 1)
    if (nrow(hit) == 0) "Regular week" else hit$festival[1]
  })
}

scale_zero_one <- function(x) {
  if (max(x) == min(x)) return(rep(0.5, length(x)))
  (x - min(x)) / (max(x) - min(x))
}

score_sale_weeks <- function(forecasts, reviews) {
  health <- reviews |>
    group_by(brand) |>
    summarise(sentiment_health = mean(actual_sentiment == "positive"), .groups = "drop")

  forecasts |>
    group_by(brand) |>
    arrange(date, .by_group = TRUE) |>
    mutate(
      demand_index = scale_zero_one(forecast),
      momentum = forecast - lag(forecast, default = first(forecast)),
      momentum_index = scale_zero_one(momentum),
      sale_window = festival_for_week(date),
      festival_score = ifelse(sale_window == "Regular week", 0, 1)
    ) |>
    ungroup() |>
    left_join(health, by = "brand") |>
    mutate(
      opportunity_score = round(100 * (
        0.55 * demand_index + 0.20 * momentum_index +
          0.15 * festival_score + 0.10 * sentiment_health
      ), 1),
      recommendation = case_when(
        opportunity_score >= 75 ~ "Strong sale window",
        opportunity_score >= 60 ~ "Good sale window",
        opportunity_score >= 45 ~ "Monitor demand",
        TRUE ~ "Low priority"
      )
    )
}

select_sale_windows <- function(data, n = 5) {
  candidates <- arrange(data, desc(opportunity_score))
  selected <- as.Date(character())
  keep_rows <- integer()
  for (i in seq_len(nrow(candidates))) {
    if (length(selected) == 0 || all(abs(candidates$date[i] - selected) >= 21)) {
      selected <- c(selected, candidates$date[i])
      keep_rows <- c(keep_rows, i)
    }
    if (length(keep_rows) == n) break
  }
  candidates[keep_rows, ]
}
