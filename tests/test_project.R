withr::local_dir("..")
suppressWarnings(suppressMessages(source("R/setup.R")))
source("config.R")
source("R/text_analysis.R")
source("R/forecast.R")

library(testthat)

test_that("text cleaning keeps negation", {
  expect_equal(clean_text("I can't recommend it!!!"), "i can not recommend it")
})

test_that("rating labels are created correctly", {
  sample <- tibble(
    review_id = as.character(1:3), review_text = rep("valid review text", 3),
    title = "", rating = c(1, 3, 5)
  )
  result <- prepare_reviews(sample)
  expect_equal(as.character(result$actual_sentiment), c("negative", "neutral", "positive"))
})

test_that("classification metrics match known values", {
  result <- classification_metrics(
    c("negative", "neutral", "positive"),
    c("negative", "positive", "positive")
  )
  expect_equal(result$accuracy[result$class == "overall"], 2 / 3)
})

test_that("sale scores stay in range", {
  forecast_sample <- tibble(
    date = seq(as.Date("2027-01-01"), by = "week", length.out = 10),
    brand = "boAt", forecast = 1:10
  )
  review_sample <- tibble(brand = "boAt", actual_sentiment = c("positive", "negative"))
  result <- score_sale_weeks(forecast_sample, review_sample)
  expect_true(all(result$opportunity_score >= 0 & result$opportunity_score <= 100))
})

test_that("project outputs exist and contain all brands", {
  required <- c(
    paths$reviews_raw, paths$trends_raw, paths$reviews_clean, paths$forecasts,
    paths$recommendations, paths$metrics, paths$sentiment_metrics, paths$aspects,
    paths$report
  )
  expect_true(all(file.exists(required)))
  reviews <- read_csv(paths$reviews_clean, show_col_types = FALSE)
  trends <- read_csv(paths$trends_raw, show_col_types = FALSE)
  expect_setequal(unique(reviews$brand), brands$brand)
  expect_setequal(unique(trends$brand), brands$brand)
  expect_gte(nrow(reviews), 500)
  expect_gte(nrow(trends), 1000)
})

test_that("forecasts beat or match a valid baseline for most brands", {
  metrics <- read_csv(paths$metrics, show_col_types = FALSE)
  winners <- metrics |>
    group_by(brand) |>
    summarise(best = min(RMSE), baseline = RMSE[model == "Seasonal naive"], .groups = "drop")
  expect_true(all(is.finite(metrics$RMSE)))
  expect_gte(sum(winners$best <= winners$baseline), 4)
})

test_that("dashboard object is valid", {
  source("app.R", local = TRUE)
  expect_s3_class(app, "shiny.appobj")
})
