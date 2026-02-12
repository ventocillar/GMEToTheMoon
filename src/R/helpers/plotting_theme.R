# ==============================================================================
# helpers/plotting_theme.R
# Consistent ggplot2 theme and plotting utilities for the thesis
# ==============================================================================

# --- Color palette ------------------------------------------------------------

thesis_palette <- MetBrewer::met.brewer("Veronese", 10)

thesis_colors <- list(
  positive  = thesis_palette[1],
  negative  = thesis_palette[4],
  neutral   = thesis_palette[6],
  highlight = thesis_palette[2],
  muted     = thesis_palette[8],
  event     = "firebrick3"
)

# --- Theme --------------------------------------------------------------------

theme_thesis <- function(base_size = 12) {
  theme_minimal(base_size = base_size) +
    theme(
      # Text
      plot.title = element_text(face = "bold", size = base_size + 2, hjust = 0),
      plot.subtitle = element_text(size = base_size, color = "grey40", hjust = 0),
      plot.caption = element_text(size = base_size - 3, color = "grey50"),
      # Axes
      axis.title = element_text(size = base_size),
      axis.title.y = element_text(angle = 90, vjust = 2),
      axis.text = element_text(size = base_size - 1),
      axis.line = element_line(color = "grey70", linewidth = 0.4),
      # Legend
      legend.position = "bottom",
      legend.title = element_text(size = base_size - 1),
      legend.text = element_text(size = base_size - 2),
      # Panel
      panel.grid.major = element_line(color = "grey92"),
      panel.grid.minor = element_blank(),
      panel.border = element_blank(),
      # Facets
      strip.text = element_text(face = "bold", size = base_size),
      # Margins
      plot.margin = margin(10, 15, 10, 10)
    )
}

# --- Save Helper --------------------------------------------------------------

save_thesis_plot <- function(plot, filename,
                             width = 30, height = 20,
                             units = "cm", dpi = 300) {
  path <- file.path(FIG_DIR, filename)
  ggsave(path, plot = plot, width = width, height = height,
         units = units, dpi = dpi, bg = "white")
  message("Saved: ", path)
}

# --- Event Line Helper --------------------------------------------------------

add_event_lines <- function(plot, events = NULL) {
  if (is.null(events)) {
    events <- data.frame(
      date = as.Date(c("2021-01-22", "2021-01-27", "2021-01-28")),
      label = c("First surge", "Peak", "RH restriction"),
      stringsAsFactors = FALSE
    )
  }
  plot +
    geom_vline(data = events, aes(xintercept = date),
               linetype = "dashed", color = thesis_colors$event, alpha = 0.7) +
    geom_text(data = events, aes(x = date, y = Inf, label = label),
              vjust = -0.5, hjust = 0.5, size = 3, color = thesis_colors$event,
              angle = 90, inherit.aes = FALSE)
}
