browser_id <- paste0(
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) ",
  "AppleWebKit/537.36 Chrome/120 Safari/537.36"
)

`%or%` <- function(x, default) if (is.null(x) || length(x) == 0) default else x

get_initial_state <- function(url) {
  response <- GET(url, user_agent(browser_id), timeout(30))
  stop_for_status(response)
  page <- read_html(content(response, "text", encoding = "UTF-8"))
  scripts <- html_text(html_elements(page, "script"))
  script <- scripts[str_detect(scripts, "window.__INITIAL_STATE__")][1]
  if (is.na(script)) stop("Flipkart page data was not found")
  text <- script |>
    str_remove("^window\\.__INITIAL_STATE__\\s*=\\s*") |>
    str_remove(";\\s*$")
  fromJSON(text, simplifyVector = FALSE)
}

review_values <- function(state) {
  slots <- state$multiWidgetState$widgetsData$slots
  review_slots <- keep(slots, function(x) identical(x$slotData$widget$type, "REVIEWS"))
  map(review_slots, function(x) x$slotData$widget$data$renderableComponents[[1]]$value)
}

parse_review_date <- function(x, today = Sys.Date()) {
  map_dbl(x, function(value) {
    value <- str_to_lower(value)
    if (value == "today") return(as.numeric(today))
    if (value == "yesterday") return(as.numeric(today - 1))
    amount <- parse_number(value)
    if (str_detect(value, "day.*ago")) return(as.numeric(today - days(amount)))
    if (str_detect(value, "month.*ago")) return(as.numeric(today %m-% months(amount)))
    if (str_detect(value, "year.*ago")) return(as.numeric(today %m-% years(amount)))
    parsed <- suppressWarnings(my(value))
    if (is.na(parsed)) return(NA_real_)
    as.numeric(as.Date(parsed))
  }) |>
    as.Date(origin = "1970-01-01")
}

scrape_review_page <- function(url, page_number) {
  parts <- parse_url(url)
  query <- c(parts$query, list(page = page_number, sortOrder = "MOST_RECENT"))
  state <- get_initial_state(modify_url(url, query = query))
  values <- review_values(state)
  map_dfr(values, function(x) {
    tibble(
      review_id = x$id,
      rating = x$rating,
      title = x$title %or% "",
      review_text = x$text %or% "",
      review_date_text = x$created,
      review_date = parse_review_date(x$created),
      verified = x$certifiedBuyer %or% FALSE,
      helpful = x$upvote$value$count %or% 0,
      city = x$location$city %or% NA_character_,
      state = x$location$state %or% NA_character_
    )
  })
}

scrape_reviews <- function(brand_table, pages = 20, pause = 0.6) {
  rows <- list()
  log <- list()

  for (i in seq_len(nrow(brand_table))) {
    for (page_number in seq_len(pages)) {
      started <- Sys.time()
      result <- tryCatch(
        scrape_review_page(brand_table$flipkart_url[i], page_number),
        error = function(e) tibble()
      )
      log[[length(log) + 1]] <- tibble(
        brand = brand_table$brand[i], page = page_number,
        rows = nrow(result), seconds = as.numeric(Sys.time() - started),
        source = "flipkart"
      )
      if (nrow(result) == 0) break
      rows[[length(rows) + 1]] <- result |>
        mutate(
          brand = brand_table$brand[i],
          product = brand_table$flipkart_product[i],
          page = page_number,
          source = "flipkart"
        )
      Sys.sleep(pause)
    }
  }

  data_result <- if (length(rows) > 0) {
    bind_rows(rows) |> distinct(review_id, .keep_all = TRUE)
  } else {
    tibble(
      review_id = character(), rating = numeric(), title = character(),
      review_text = character(), review_date_text = character(),
      review_date = as.Date(character()), verified = logical(),
      helpful = numeric(), city = character(), state = character(),
      brand = character(), product = character(), page = integer(),
      source = character()
    )
  }
  
  list(
    data = data_result,
    log = bind_rows(log)
  )
}

scrape_trends <- function(brand_table) {
  result <- gtrends(
    keyword = brand_table$trend_term,
    geo = "IN",
    time = "today+5-y"
  )$interest_over_time

  result |>
    transmute(
      date = as.Date(date),
      trend_term = keyword,
      interest = as.numeric(str_replace(as.character(hits), "<1", "0.5"))
    ) |>
    left_join(select(brand_table, brand, trend_term), by = "trend_term") |>
    select(date, brand, trend_term, interest)
}

# Amazon scraping functions
scrape_amazon_page <- function(asin, page_number = 1) {
  base_url <- "https://www.amazon.in/product-reviews"
  url <- paste0(base_url, "/", asin, "/")
  
  query <- list(
    ie = "UTF8",
    reviewerType = "all_reviews",
    pageNumber = page_number,
    sortBy = "recent"
  )
  
  response <- GET(
    url, 
    query = query,
    user_agent(browser_id),
    timeout(30),
    add_headers(
      "Accept-Language" = "en-US,en;q=0.9",
      "Accept" = "text/html,application/xhtml+xml"
    )
  )
  
  if (status_code(response) != 200) {
    return(tibble())
  }
  
  page <- read_html(content(response, "text", encoding = "UTF-8"))
  
  reviews <- html_elements(page, "[data-hook='review']")
  
  if (length(reviews) == 0) {
    return(tibble())
  }
  
  map_dfr(reviews, function(review) {
    review_id <- html_attr(review, "id") %or% NA_character_
    
    rating_node <- html_element(review, "[data-hook='review-star-rating']")
    rating_text <- html_text(rating_node) %or% "0.0"
    rating <- as.numeric(str_extract(rating_text, "\\d+\\.?\\d*"))
    
    title_node <- html_element(review, "[data-hook='review-title']")
    title <- html_text(title_node) %or% ""
    title <- str_squish(title)
    
    text_node <- html_element(review, "[data-hook='review-body']")
    review_text <- html_text(text_node) %or% ""
    review_text <- str_squish(review_text)
    
    date_node <- html_element(review, "[data-hook='review-date']")
    date_text <- html_text(date_node) %or% ""
    date_text <- str_squish(date_text)
    
    verified_node <- html_element(review, "[data-hook='avp-badge']")
    verified <- !is.na(html_text(verified_node))
    
    helpful_node <- html_element(review, "[data-hook='helpful-vote-statement']")
    helpful_text <- html_text(helpful_node) %or% "0"
    helpful <- parse_number(helpful_text)
    helpful <- ifelse(is.na(helpful), 0, helpful)
    
    tibble(
      review_id = review_id,
      rating = rating,
      title = title,
      review_text = review_text,
      review_date_text = date_text,
      review_date = parse_amazon_date(date_text),
      verified = verified,
      helpful = helpful,
      city = NA_character_,
      state = NA_character_
    )
  })
}

parse_amazon_date <- function(date_strings) {
  map(date_strings, function(text) {
    # Amazon India format: "Reviewed in India on 15 October 2023"
    date_part <- str_extract(text, "\\d{1,2}\\s+[A-Za-z]+\\s+\\d{4}")
    
    if (is.na(date_part)) {
      return(as.Date(NA))
    }
    
    parsed <- suppressWarnings(dmy(date_part))
    
    if (is.na(parsed)) {
      parsed <- suppressWarnings(parse_date_time(date_part, orders = c("d B Y", "d b Y")))
      if (!is.na(parsed)) {
        return(as.Date(parsed))
      }
    }
    
    return(as.Date(parsed))
  }) |>
    do.call(c, args = _)
}

scrape_amazon_reviews <- function(brand_table, pages = 10, pause = 0.6) {
  rows <- list()
  log <- list()
  
  for (i in seq_len(nrow(brand_table))) {
    message(sprintf("Scraping Amazon reviews for %s...", brand_table$brand[i]))
    
    for (page_number in seq_len(pages)) {
      started <- Sys.time()
      result <- tryCatch(
        scrape_amazon_page(brand_table$amazon_asin[i], page_number),
        error = function(e) {
          message(sprintf("  Error on page %d: %s", page_number, e$message))
          tibble()
        }
      )
      
      log[[length(log) + 1]] <- tibble(
        brand = brand_table$brand[i],
        page = page_number,
        rows = nrow(result),
        seconds = as.numeric(Sys.time() - started),
        source = "amazon"
      )
      
      if (nrow(result) == 0) break
      
      rows[[length(rows) + 1]] <- result |>
        mutate(
          brand = brand_table$brand[i],
          product = brand_table$amazon_product[i],
          page = page_number,
          source = "amazon"
        )
      
      message(sprintf("  Page %d: %d reviews collected", page_number, nrow(result)))
      Sys.sleep(pause)
    }
  }
  
  data_result <- if (length(rows) > 0) {
    bind_rows(rows) |> distinct(review_id, .keep_all = TRUE)
  } else {
    tibble(
      review_id = character(), rating = numeric(), title = character(),
      review_text = character(), review_date_text = character(),
      review_date = as.Date(character()), verified = logical(),
      helpful = numeric(), city = character(), state = character(),
      brand = character(), product = character(), page = integer(),
      source = character()
    )
  }
  
  list(
    data = data_result,
    log = bind_rows(log)
  )
}
