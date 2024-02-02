knitr::opts_chunk$set(
    echo = TRUE,
    message = FALSE,
    warning = FALSE,
    cache = FALSE,
    eval = FALSE,
    fig.height = 9,
    fig.width = 11
)
options(dplyr.print_max = 100)
# options(blogdown.method = "markdown")

library(tidyverse)
library(pdftools)
library(gt)
library(tidytext)
library(rvest)
library(echarts4r)

# download.file(
#   "https://blog.kakaocdn.net/dn/CnVbv/btqUmJjbuWJ/OfaJTFKkUorXxXKxIYnuB1/tfile.pdf",
#   "script.pdf" ## path for a place in your computer
# )

data <-
  tibble(text = pdf_text(
    stringr::str_interp("content/posts/modern-family/script.pdf")
  ))

data <- data |>
    mutate(
        ep = str_extract(text, "(?<=Season 1x)[0-9]{2}"),
        page = trimws(str_extract(text, "(?<=page)\\s?[0-9]+"))
    )

data2 <- data |>
  group_by(ep, page) |>
  group_split() |>
  map(function(.x) {
    text <- str_c(.x$text, collapse = "")
    text <- str_split(text, "\n")[[1]]
    
    x <-
      map(str_split(text, regex("\\s{3,100}")), function(.w) {
        if (length(.w) == 1 && .w == "") {
          tibble(c1 = "", c2 = "")
        } else if (length(.w) == 1) {
          tibble(c1 = .w[1], c2 = "")
        } else if (length(.w) == 3) {
          tibble(c1 = .w[1], c2 = .w[3])
        } else {
          tibble(c1 = .w[1], c2 = .w[2])
        }
      }) |>
      bind_rows()
    
    c1 <-
      str_replace(x$c1,
                  "(?<=^\\w{1,15})\\s?:\\s+|(?<=^\\w{1,15} \\w{1,15})\\s?:\\s+",
                  ": ")
    c1 <-
      str_replace(c1,
                  "(?<=^\\w{1,15})\\s?;\\s+|(?<=^\\w{1,15} \\w{1,15})\\s?;\\s+",
                  ": ")
    
    c2 <-
      str_replace(x$c2,
                  "(?<=^\\w{1,15})\\s?:\\s+|(?<=^\\w{1,15} \\w{1,15})\\s?:\\s+",
                  ": ")
    c2 <-
      str_replace(c2,
                  "(?<=^\\w{1,15})\\s?;\\s+|(?<=^\\w{1,15} \\w{1,15})\\s?;\\s+",
                  ": ")
    
    cs <- c(c1, c2)
    
    tibble(script = cs,
           ep = unique(.x$ep),
           page = unique(.x$page))
    
  }) |>
  bind_rows()

data3 <- data2 |>
  filter(str_detect(script, "Modern Family Season|OPENING CREDITS", negate = TRUE) &
           script != "")

data4 <- data3 |>
    mutate(
        script = str_replace(script, "\\s+:\\s+", ": "),
        script = str_replace(script, "\\s+;\\s+", "; "),
        not_a_line = str_detect(script, "[\\w\\s]+(?=: )", negate = TRUE),
        not_a_line = ifelse(script == "", FALSE, not_a_line)
    )

data4 |> 
  slice(30:34)

data4 <- data4 |>
    mutate(
        script = str_replace(script, "(?<=\\w)\\s+:\\s+", ":"),
        script = str_replace(script, "(?<=\\w)\\s+;\\s+", "; "),
        not_a_line = str_detect(script, "[A-z]+(?=:)", negate = TRUE),
        not_a_line = ifelse(script == "", FALSE, not_a_line)
    )

missing_lines <- which(data4$not_a_line == TRUE)
for (i in rev(missing_lines)) {
    data4$script[i - 1] <- str_c(data4$script[i - 1], " ", data4$script[i])
}
data4 <- data4[-missing_lines, ]
data4 <- data4 |>
    select(-not_a_line)

data4 |> 
  slice(22:23)

data5 <- data4 |>
    filter(script != "") |> 
    mutate(
        character = str_extract(script, "[\\w\\s]+(?=:)"),
        character = trimws(tolower(character)),

        script2 = trimws(str_replace(script, "^[\\w\\s]+:", "")),
        line = script2,
        line_length = nchar(script2)
    ) |> 
    select(page, ep, character, line, script)

main_characters <- data5 |>
    count(character, sort = TRUE) |>
    mutate(pct = n / sum(n), pct_acc = cumsum(pct)) |>
    filter(pct_acc <= 0.9) |>
    pull(character)

other_characters <- data5 |>
    count(character, sort = TRUE) |>
    mutate(pct = n / sum(n), pct_acc = cumsum(pct)) |>
    filter(pct_acc > 0.9) |>
    pull(character)

fix_characters <- map(main_characters, function(.x) {
  other_characters[stringdist::stringdist(.x, other_characters, "jw") <= 0.15]
}) |>
  setNames(main_characters)

fix_characters <- fix_characters[which(sapply(fix_characters, length) > 0)]
fix_characters[[3]] <- fix_characters[[3]][-1]

for (i in 1:length(fix_characters)) {
  for (j in 1:length(fix_characters[[i]])) {
    data5$character[data5$character == fix_characters[[i]][[j]]] <-
      names(fix_characters)[i]
  }
}

data5 |>
    slice(1:10) |>
    gt(caption = "Ten first rows of the data.frame with additional informations") |>
    cols_align(
        align = "center",
        columns = c(ep, page, character)
    ) |>
    tab_style(
        locations = cells_column_labels(columns = everything()),
        style = list(
            cell_borders(sides = "bottom", weight = px(3)),
            cell_text(weight = "bold")
        )
    )

transformers <- import("transformers")
classifier <- transformers$pipeline(
  "text-classification",
  model = 'bhadresh-savani/distilbert-base-uncased-emotion',
  return_all_scores = TRUE)

# Applying the model for each character's line 

data6 <- data5 |>
  mutate(sent = classifier(line))

data7 <- data6 |>
  bind_cols(map(data6$sent, function(.x) {
    tibble(variable = unlist(map(.x, "label")),
           score = unlist(map(.x, "score"))) |>
      spread(variable, score)
  }) |>
    bind_rows()) |>
  select(-sent)

data7 |>
  slice(1:10) |> 
  select(-page, -ep, -script) |> 
  gt(caption = "Ten first rows with the results from the pre-trained model") |>
  cols_align(align = "center",) |>
  tab_style(
    locations = cells_column_labels(columns = everything()),
    style = list(
      cell_borders(sides = "bottom", weight = px(3)),
      cell_text(weight = "bold")
    )
  ) |> 
  fmt_percent(columns = c(anger,fear,joy,love,sadness,surprise))

unigram <- data7 |> 
  filter(character %in% main_characters) |> 
  select(character, line) |>
  unnest_tokens(word, line) |>
  count(character, word) |> 
  bind_tf_idf(word, character, n) |> 
  filter(!word %in% stop_words$word) |> 
  drop_na() |> 
  arrange(desc(n)) |> 
  ungroup()

i <- 1


## I got some pictures for each character from google images ##
main_characters_img <- c(
  "https://res.cloudinary.com/andryas/image/upload/v1668181537/blog/maxresdefault.jpg",
  "https://res.cloudinary.com/andryas/image/upload/v1668195080/blog/claire-face-feature-modern-family.avif",
  "https://res.cloudinary.com/andryas/image/upload/v1668195382/blog/a3062bb3-5115-4a88-8b2e-b06e39575f3a.jpg",
  "https://res.cloudinary.com/andryas/image/upload/v1668195381/blog/maxresdefault2.jpg",
  "https://res.cloudinary.com/andryas/image/upload/v1668195380/blog/Cam-Tucker-750x402.jpg",
  "https://res.cloudinary.com/andryas/image/upload/v1668195379/blog/cda.jpg",
  "https://res.cloudinary.com/andryas/image/upload/v1668195379/blog/98.webp",
  "https://res.cloudinary.com/andryas/image/upload/v1668195377/blog/MV5BNTI1NTEyNWEtNDdiYi00MzZiLTgxNGQtZjJkMmZkN2I4NDk3XkEyXkFqcGdeQXVyNTM3MDMyMDQ_._V1_.jpg",
  "https://res.cloudinary.com/andryas/image/upload/v1668195484/blog/bea72840602ecfce51f2d52bf0a7bd8e.png",
  "https://res.cloudinary.com/andryas/image/upload/v1668195376/blog/modern-family-cast-season-1-ariel-winter-1565016010.jpg",
  "https://res.cloudinary.com/andryas/image/upload/v1668195365/blog/dylan-modern-family-musicas.jpg"
)


plot_sent <- data7 |> 
  filter(character == !!main_characters[i]) |> 
  summarise_at(vars(anger, fear, joy, love, sadness, surprise), mean) |> 
  gather(variable, value) |> 
  e_charts(variable) |> 
  e_radar(
    value, 
    max = 0.6, 
    areaStyle = list(),
    legend = FALSE
  ) |> 
  e_tooltip(trigger = "item")

plot_unigram <- unigram |>
  filter(character == !!main_characters[i]) |>
  select(word, tf_idf) |>
  arrange(desc(tf_idf)) |>
  slice(1:100) |>
  e_color_range(tf_idf, color) |>
  e_charts() |>
  e_cloud(word, tf_idf, color, shape = "circle", ) |>
  e_title(str_c(main_characters[i], " - most used words"))

shiny::fluidRow(
  shiny::fluidRow(
    style = "width: 100%",
    class = "align-items-center",
    shiny::column(6, shiny::img(src=main_characters_img[i], height=300, width=300)),
    shiny::column(6, htmltools::div(plot_sent)),
  ),
  shiny::fluidRow(
    style = "width: 100%",
    plot_unigram
  )
)

tags <- map(1:length(main_characters), function(i) {
  plot_sent <- data7 |>
    filter(character == !!main_characters[i]) |>
    summarise_at(vars(anger, fear, joy, love, sadness, surprise), mean) |>
    gather(variable, value) |>
    e_charts(variable) |>
    e_pie(value, roseType = "radius", legend = FALSE)
  
  plot_unigram <- unigram |>
    filter(character == !!main_characters[i]) |>
    select(word, tf_idf) |>
    arrange(desc(tf_idf)) |>
    slice(1:100) |>
    e_color_range(tf_idf, color) |>
    e_charts() |>
    e_cloud(word, tf_idf, color, shape = "circle", ) |>
    e_title(str_c(main_characters[i], " - most used words"))
  
  shiny::fluidRow(
    shiny::fluidRow(
      style = "width: 100%",
      class = "align-items-center",
      shiny::column(6, shiny::img(src=main_characters_img[i], height=300, width=300)),
      shiny::column(6, htmltools::div(plot_sent)),
    ),
    shiny::fluidRow(
      style = "width: 100%",
      plot_unigram
    )
  )
})

shiny::tagList(tags)
