#!/usr/local/bin/Rscript

# generate dataset with certain seed
set.seed(1)
data <- dyntoy::generate_dataset(
  id = "specific_example/template",
  num_cells = 30,
  num_features = 40,
  model = "tree",
  normalise = FALSE
)

# add method specific args (if needed)
data$params <- list(iter = 10)

data$seed <- 1

# write example dataset to file
file <- commandArgs(trailingOnly = TRUE)[[1]]
dynutils::write_h5(data, file)
