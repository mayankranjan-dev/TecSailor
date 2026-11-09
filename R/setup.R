packages <- c(
  "dplyr", "tidyr", "purrr", "readr", "stringr", "tibble", "ggplot2",
  "rvest", "httr", "jsonlite", "tidytext", "lubridate", "forecast",
  "gtrendsR", "scales", "shiny", "shinydashboard", "testthat"
)

missing <- packages[!packages %in% rownames(installed.packages())]
if (length(missing) > 0) install.packages(missing, repos = "https://cloud.r-project.org")

suppressWarnings(suppressPackageStartupMessages(
  invisible(lapply(packages, library, character.only = TRUE))
))

theme_set(theme_minimal(base_size = 12))
