library(tidyverse)

cars_data <- mtcars %>%
  rownames_to_column("model") %>%
  mutate(cylinders = factor(cyl))

ggplot(cars_data, aes(x = wt, y = mpg, color = cylinders)) +
  geom_point(size = 3) +
  labs(
    title = "Fuel Efficiency vs Car Weight",
    x = "Weight (1,000 lbs)",
    y = "Miles per gallon",
    color = "Cylinders"
  )

# Short reflection:
# I learned that ggplot2 builds a plot step by step: first the data and
# variables, then layers such as points. I also learned that labels and legends
# make the graph easier to read.
