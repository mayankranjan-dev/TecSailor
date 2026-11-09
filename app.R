source("R/setup.R")
source("config.R")

trends <- read_csv(paths$trends_raw, show_col_types = FALSE) |> mutate(date = as.Date(date))
reviews <- read_csv(paths$reviews_clean, show_col_types = FALSE) |> mutate(review_date = as.Date(review_date))
forecasts <- read_csv(paths$forecasts, show_col_types = FALSE) |> mutate(date = as.Date(date))
scores <- read_csv("data/processed/all_sale_scores.csv", show_col_types = FALSE) |> mutate(date = as.Date(date))
recommendations <- read_csv(paths$recommendations, show_col_types = FALSE) |> mutate(date = as.Date(date))
metrics <- read_csv(paths$metrics, show_col_types = FALSE)
aspects <- read_csv(paths$aspects, show_col_types = FALSE)

ui <- dashboardPage(
  dashboardHeader(title = "TecSailor"),
  dashboardSidebar(
    selectInput("brand", "Choose a brand", choices = brands$brand, selected = "boAt"),
    helpText("Demand is based on relative Google search interest in India."),
    helpText("The score supports planning and is not a guarantee of sales.")
  ),
  dashboardBody(
    fluidRow(
      valueBoxOutput("best_week", width = 4),
      valueBoxOutput("review_health", width = 4),
      valueBoxOutput("best_model", width = 4)
    ),
    fluidRow(
      box(width = 8, title = "Demand history and forecast", plotOutput("forecast_plot", height = 330)),
      box(width = 4, title = "Recommended sale windows", tableOutput("sale_table"))
    ),
    fluidRow(
      box(width = 6, title = "Promotion opportunity", plotOutput("score_plot", height = 300)),
      box(width = 6, title = "Review sentiment", plotOutput("sentiment_plot", height = 300))
    ),
    fluidRow(
      box(width = 7, title = "What customers discuss", plotOutput("aspect_plot", height = 330)),
      box(width = 5, title = "Forecast model backtest", tableOutput("metric_table"))
    )
  )
)

server <- function(input, output, session) {
  selected_trend <- reactive(filter(trends, brand == input$brand))
  selected_forecast <- reactive(filter(forecasts, brand == input$brand))
  selected_scores <- reactive(filter(scores, brand == input$brand))
  selected_reviews <- reactive(filter(reviews, brand == input$brand))

  output$best_week <- renderValueBox({
    row <- recommendations |> filter(brand == input$brand) |> slice_max(opportunity_score, n = 1)
    valueBox(format(row$date, "%d %b %Y"), "Best upcoming sale week", icon = icon("calendar"), color = "green")
  })

  output$review_health <- renderValueBox({
    value <- mean(selected_reviews()$actual_sentiment == "positive")
    valueBox(percent(value, accuracy = 0.1), "Positive customer ratings", icon = icon("star"), color = "yellow")
  })

  output$best_model <- renderValueBox({
    row <- metrics |> filter(brand == input$brand) |> slice_min(RMSE, n = 1)
    valueBox(row$model, paste("Best RMSE:", round(row$RMSE, 2)), icon = icon("chart-line"), color = "aqua")
  })

  output$forecast_plot <- renderPlot({
    history <- selected_trend() |> slice_tail(n = 104)
    future <- selected_forecast()
    ggplot() +
      geom_line(data = history, aes(date, interest), colour = "#2c7fb8", linewidth = 0.8) +
      geom_ribbon(data = future, aes(date, ymin = lower_80, ymax = upper_80), fill = "#7fcdbb", alpha = 0.3) +
      geom_line(data = future, aes(date, forecast), colour = "#d7301f", linewidth = 0.9) +
      labs(x = NULL, y = "Relative interest")
  })

  output$sale_table <- renderTable({
    recommendations |>
      filter(brand == input$brand) |>
      transmute(Week = format(date, "%d %b %Y"), Score = opportunity_score, Event = sale_window) |>
      slice_head(n = 5)
  }, striped = TRUE, spacing = "s")

  output$score_plot <- renderPlot({
    ggplot(selected_scores(), aes(date, opportunity_score, colour = recommendation)) +
      geom_line(colour = "grey70") +
      geom_point(size = 2) +
      scale_colour_manual(values = c(
        "Strong sale window" = "#1a9850", "Good sale window" = "#91cf60",
        "Monitor demand" = "#fee08b", "Low priority" = "#d73027"
      )) +
      labs(x = NULL, y = "Score", colour = NULL) +
      theme(legend.position = "bottom")
  })

  output$sentiment_plot <- renderPlot({
    selected_reviews() |>
      count(actual_sentiment) |>
      mutate(share = n / sum(n)) |>
      ggplot(aes(actual_sentiment, share, fill = actual_sentiment)) +
      geom_col(width = 0.65) +
      scale_y_continuous(labels = percent) +
      scale_fill_manual(values = c(negative = "#d73027", neutral = "#fdae61", positive = "#1a9850"), guide = "none") +
      labs(x = NULL, y = "Share")
  })

  output$aspect_plot <- renderPlot({
    aspects |>
      filter(brand == input$brand) |>
      group_by(aspect) |>
      summarise(mentions = sum(mentions), .groups = "drop") |>
      slice_max(mentions, n = 8) |>
      ggplot(aes(mentions, reorder(aspect, mentions))) +
      geom_col(fill = "#2c7fb8") +
      labs(x = "Mentions", y = NULL)
  })

  output$metric_table <- renderTable({
    metrics |>
      filter(brand == input$brand) |>
      mutate(across(c(MAE, RMSE, WAPE), ~ round(.x, 3))) |>
      arrange(RMSE)
  }, striped = TRUE)
}

app <- shinyApp(ui, server)
