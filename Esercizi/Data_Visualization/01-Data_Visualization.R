# Run this line once if tidyverse is not installed:
# install.packages("tidyverse")

library(tidyverse)

# Dataset: mtcars
# Variables used:
# - wt: car weight
# - mpg: miles per gallon
# - cyl: number of cylinders
# - am: transmission type
cars_data <- mtcars %>%
  rownames_to_column("model") %>%
  mutate(
    cylinders = factor(
      cyl,
      levels = c(4, 6, 8),
      labels = c("4 cylinders", "6 cylinders", "8 cylinders")
    ),
    transmission = factor(
      am,
      levels = c(0, 1),
      labels = c("Automatic", "Manual")
    )
  )

fuel_plot <- ggplot(cars_data, aes(x = wt, y = mpg)) +
  geom_smooth(
    method = "lm",
    formula = y ~ x,
    se = TRUE,
    color = "#2F4858",
    fill = "#9FC5D1",
    linewidth = 1,
    alpha = 0.25
  ) +
  geom_point(
    aes(fill = cylinders, shape = transmission),
    color = "white",
    size = 4,
    stroke = 0.9,
    alpha = 0.95
  ) +
  scale_fill_manual(
    values = c(
      "4 cylinders" = "#2A9D8F",
      "6 cylinders" = "#E9C46A",
      "8 cylinders" = "#E76F51"
    )
  ) +
  scale_shape_manual(values = c("Automatic" = 21, "Manual" = 24)) +
  scale_x_continuous(breaks = seq(1.5, 5.5, 0.5)) +
  scale_y_continuous(breaks = seq(10, 35, 5)) +
  coord_cartesian(xlim = c(1.4, 5.6), ylim = c(9.5, 35.5)) +
  labs(
    title = "Fuel Efficiency vs Car Weight",
    subtitle = "Lighter cars generally travel farther per gallon",
    x = "Weight (1,000 lbs)",
    y = "Miles per gallon",
    fill = "Cylinders",
    shape = "Transmission",
    caption = "Source: mtcars dataset"
  ) +
  guides(
    fill = guide_legend(
      order = 1,
      override.aes = list(shape = 21, color = "#333333", size = 4, alpha = 1)
    ),
    shape = guide_legend(
      order = 2,
      override.aes = list(fill = "#BFC7C9", color = "#333333", size = 4, alpha = 1)
    )
  ) +
  theme_light(base_size = 13) +
  theme(
    plot.background = element_rect(fill = "#FAFAF7", color = NA),
    panel.background = element_rect(fill = "#FAFAF7", color = NA),
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(color = "#E2E2DC", linewidth = 0.4),
    plot.title = element_text(size = 20, face = "bold", hjust = 0.5),
    plot.subtitle = element_text(size = 12, color = "#555555", hjust = 0.5),
    plot.caption = element_text(size = 9, color = "#666666", hjust = 1),
    axis.title = element_text(size = 12, face = "bold"),
    axis.text = element_text(size = 10, color = "#333333"),
    legend.position = "top",
    legend.title = element_text(size = 10, face = "bold"),
    legend.text = element_text(size = 9),
    legend.background = element_blank(),
    legend.key = element_blank()
  )

fuel_plot

ggsave(
  filename = "fuel_efficiency_weight.png",
  plot = fuel_plot,
  width = 9,
  height = 6,
  dpi = 300
)
