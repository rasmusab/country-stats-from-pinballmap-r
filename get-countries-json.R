# This script fetches the latest country statistics from pinballmap.com, 
# saves the data in JSON format, and tracks historical changes in a CSV file.

library(tidyverse)
library(httr2)
library(jsonlite)
library(svglite)

# Fetch the latest country statistics from pinballmap.com
response <- req_perform(request("https://pinballmap.com/api/v1/locations/countries.json"))

if (resp_status(response) != 200) {
  stop("Failed to retrieve data: ", resp_status(response))
}

countries_json <- resp_body_json(response)

# Write the JSON data to a file in pretty print format
# Why pretty print? Because it diffs better in git.
write_json(countries_json, "countries.json", pretty = TRUE, auto_unbox = TRUE)

# And stick it in the history folder with a timestamp, as well.
dir.create("json-history", showWarnings = FALSE)
history_file_path <- paste0("json-history/", format(Sys.time(), "%Y-%m-%d_"), "countries.json")
file.copy("countries.json", history_file_path)

# Read all historical JSON files and prepare them for analysis
json_fnames <- list.files("json-history", pattern = "*.json", full.names = TRUE)
countries_history <- 
  map(json_fnames, function(fname) {
    fromJSON(fname) |>
      select(country, location_count) |>
      mutate(date = as.Date(str_extract(fname, "\\d{4}-\\d{2}-\\d{2}")))
  }) |> 
  bind_rows() |>
  arrange(date, country)

# Save the countries' history to a CSV file
write_csv(countries_history, "countries-history.csv")

# That concludes the neccecary steps to fetch and store the pinballmap's data
# buuuuut, let's also plot the timeseries for the top 10 current contries,
# just for the fun of it :) 

latest_date <- max(countries_history$date)

top_10_countries <- countries_history |>
  filter(date == latest_date) |>
  slice_max(location_count, n = 10) |> 
  pull(country)

top_10_countries_history <- countries_history |>
  filter(country %in% top_10_countries) |>
  mutate(country = fct_relevel(country, top_10_countries))

# Plot the top 10 countries' history
top_10_countries_plot <- ggplot(top_10_countries_history, aes(x = date, y = location_count, color = country)) +
  geom_line() +
  geom_point() +
  scale_x_date(date_breaks = "1 month", date_labels = "%Y %b") +
  scale_y_log10(labels = scales::comma) +
  labs(
    title = "Top 10 countries with most public pinball locations",
    subtitle = paste0("as of ", latest_date),
    x = "",
    y = "Number of locations"
  )

ggsave("top-10-countries.svg", top_10_countries_plot, width = 7, height = 4)
