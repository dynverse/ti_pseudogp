#!/usr/local/bin/Rscript

task <- dyncli::main()

library(jsonlite)
library(readr)
library(dplyr)
library(purrr)

library(rstan)
library(coda)
library(MCMCglmm)
library(dyndimred)

#   ____________________________________________________________________________
#   Load data                                                               ####

params <- task$params
expression <- as.matrix(task$expression)

#   ____________________________________________________________________________
#   Infer trajectory                                                        ####

# perform dimreds
dimred_names <- params$dimreds
spaces <- map(dimred_names, ~ dyndimred::dimred(expression, method = ., ndim = 2)) # only 2 dimensions per dimred are allowed

# TIMING: done with preproc
checkpoints <- list(method_afterpreproc = as.numeric(Sys.time()))

# fit probabilistic pseudotime model
fit <- pseudogp::fitPseudotime(
  X = spaces,
  smoothing_alpha = params$smoothing_alpha,
  smoothing_beta = params$smoothing_beta,
  iter = params$iter,
  chains = params$chains,
  initialise_from = params$initialise_from,
  pseudotime_var = params$pseudotime_var,
  pseudotime_mean = params$pseudotime_mean
)

# TIMING: done with method
checkpoints$method_aftermethod <- as.numeric(Sys.time())

# extract pseudotime
pst <- rstan::extract(fit, pars = "t")$t
tmcmc <- coda::mcmc(pst)
pseudotime <- MCMCglmm::posterior.mode(tmcmc) %>%
  setNames(rownames(expression))

# return output
output <- lst(
  cell_ids = names(pseudotime),
  pseudotime = pseudotime,
  timings = checkpoints
)

#   ____________________________________________________________________________
#   Save output                                                             ####

dynwrap::wrap_data(cell_ids = names(pseudotime)) %>%
  dynwrap::add_linear_trajectory(pseudotime = pseudotime) %>%
  dynwrap::add_timings(checkpoints) %>%
  dyncli::write_output(task$output)
