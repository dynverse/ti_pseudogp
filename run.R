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

parameters <- task$parameters
expression <- as.matrix(task$expression)

#   ____________________________________________________________________________
#   Infer trajectory                                                        ####

# perform dimreds
dimred_names <- parameters$dimreds
spaces <- map(dimred_names, ~ dyndimred::dimred(expression, method = ., ndim = 2)) # only 2 dimensions per dimred are allowed

# TIMING: done with preproc
checkpoints <- list(method_afterpreproc = as.numeric(Sys.time()))

# fit probabilistic pseudotime model
fit <- pseudogp::fitPseudotime(
  X = spaces,
  smoothing_alpha = parameters$smoothing_alpha,
  smoothing_beta = parameters$smoothing_beta,
  iter = parameters$iter,
  chains = parameters$chains,
  initialise_from = parameters$initialise_from,
  pseudotime_var = parameters$pseudotime_var,
  pseudotime_mean = parameters$pseudotime_mean
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
