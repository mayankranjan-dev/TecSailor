brand_colors <- c(
  "boAt" = "#e63946", "Noise" = "#457b9d", "Boult" = "#2a9d8f",
  "realme" = "#f4a261", "JBL" = "#6a4c93"
)

save_chart <- function(plot, file, width = 10, height = 6) {
  ggsave(file.path(paths$figures, file), plot, width = width, height = height, dpi = 150, bg = "white")
}

plot_market_trends <- function(trends) {
  ggplot(trends, aes(date, interest, colour = brand)) +
    geom_line(linewidth = 0.75) +
    scale_colour_manual(values = brand_colors) +
    labs(
      title = "Search interest for wireless audio brands in India",
      subtitle = "Weekly Google Trends index; values are relative, not unit sales",
      x = NULL, y = "Search interest", colour = NULL
    ) +
    theme(legend.position = "bottom")
}

plot_forecasts <- function(trends, forecasts) {
  recent <- trends |> group_by(brand) |> slice_tail(n = 52) |> ungroup()
  ggplot() +
    geom_line(data = recent, aes(date, interest, colour = brand), linewidth = 0.8) +
    geom_ribbon(data = forecasts, aes(date, ymin = lower_80, ymax = upper_80, fill = brand), alpha = 0.18) +
    geom_line(data = forecasts, aes(date, forecast, colour = brand), linewidth = 0.9, linetype = "dashed") +
    facet_wrap(~brand, scales = "free_y") +
    scale_colour_manual(values = brand_colors, guide = "none") +
    scale_fill_manual(values = brand_colors, guide = "none") +
    labs(title = "One-year demand outlook", subtitle = "Solid line: history; dashed line: forecast; band: 80% interval", x = NULL, y = "Interest")
}

plot_sale_scores <- function(scores) {
  ggplot(scores, aes(date, opportunity_score, colour = brand)) +
    geom_hline(yintercept = c(45, 60, 75), colour = "grey80", linetype = "dotted") +
    geom_line(linewidth = 0.9) +
    facet_wrap(~brand) +
    scale_colour_manual(values = brand_colors, guide = "none") +
    labs(title = "Promotion opportunity score", subtitle = "Demand 55%, momentum 20%, festival timing 15%, review health 10%", x = NULL, y = "Score out of 100")
}

plot_sentiment <- function(reviews) {
  reviews |>
    count(brand, actual_sentiment) |>
    group_by(brand) |>
    mutate(share = n / sum(n)) |>
    ungroup() |>
    ggplot(aes(brand, share, fill = actual_sentiment)) +
    geom_col() +
    scale_y_continuous(labels = percent) +
    scale_fill_manual(values = c(negative = "#d73027", neutral = "#fdae61", positive = "#1a9850")) +
    labs(title = "Customer sentiment from Flipkart ratings", x = NULL, y = "Share of reviews", fill = NULL)
}

plot_aspects <- function(aspects) {
  aspects |>
    group_by(brand, aspect) |>
    summarise(mentions = sum(mentions), .groups = "drop") |>
    group_by(brand) |>
    slice_max(mentions, n = 6, with_ties = FALSE) |>
    ungroup() |>
    ggplot(aes(mentions, reorder_within(aspect, mentions, brand), fill = brand)) +
    geom_col(show.legend = FALSE) +
    facet_wrap(~brand, scales = "free") +
    scale_y_reordered() +
    scale_fill_manual(values = brand_colors) +
    labs(title = "Most discussed product aspects", x = "Mentions", y = NULL)
}

plot_model_metrics <- function(metrics) {
  ggplot(metrics, aes(RMSE, reorder(model, RMSE), colour = brand)) +
    geom_point(size = 3) +
    facet_wrap(~brand, scales = "free_x") +
    scale_colour_manual(values = brand_colors, guide = "none") +
    labs(title = "Forecast backtest: lower RMSE is better", subtitle = "Last 26 weeks used as the test period", x = "RMSE", y = NULL)
}
