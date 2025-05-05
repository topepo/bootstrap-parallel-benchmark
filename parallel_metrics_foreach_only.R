library(dplyr)
library(rsample)
library(yardstick)
library(parallel)
library(sessioninfo)
library(syrup)
# more library() calls below

rand_int <- sample.int(1000, 1)

# ------------------------------------------------------------------------------

compute_metrics <- function(split) {
  require(rsample)
  require(yardstick)
  dat <- analysis(split)
  mtr <- metric_set(rmse, rsq, mae, ccc)
  mtr(dat, y, .pred)
}

pkgs <- c("yardstick", "rsample")

# ------------------------------------------------------------------------------

data_size <- 10000
boot_size <- 5000

set.seed(1)
dat <- tibble(y = rnorm(data_size)) |>
  mutate(.pred = y + rnorm(data_size, sd = 0.1))

set.seed(2)
rs <- bootstraps(dat, times = boot_size)

# example iteration
compute_metrics(rs$splits[[1]])

# ------------------------------------------------------------------------------

seq_time <-
  system.time({
    set.seed(3)
    metrics <- lapply(rs$splits, compute_metrics)
  })

seq_time

seq_time <- tibble::as_tibble_row(seq_time) |>
  mutate(
    parallel = FALSE,
    run = rand_int,
    num_workers = parallelly::availableCores(),
    framework = "foreach",
    backend = "multisession",
    platform = .Platform$pkgType
  )

# ------------------------------------------------------------------------------

library(parallelly)
library(foreach)
library(doParallel)

cores <- min(parallelly::availableCores(), 12)
cl <- makePSOCKcluster(cores)
registerDoParallel(cl)

suffix <- paste0("-foreach-foreach-", rand_int, ".RData")

# ------------------------------------------------------------------------------

par_time <-
  system.time({
    set.seed(3)
    metrics <-
      foreach(i = boot_size, .packages = pkgs) %dopar%
      compute_metrics(rs$splits[[i]])
  })

par_time

par_time <- tibble::as_tibble_row(par_time) |>
  mutate(
    parallel = TRUE,
    run = rand_int,
    num_workers = parallelly::availableCores(),
    framework = "foreach",
    backend = "multisession",
    platform = .Platform$pkgType
  )

res <- bind_rows(seq_time, par_time)

# ------------------------------------------------------------------------------

main_pid <- Sys.getpid()

monitor <- syrup({
  set.seed(3)
  metrics <-
    foreach(i = boot_size) %dopar%
    compute_metrics(rs$splits[[i]])
}, interval = 1 / 20)

monitor <- monitor |>
  mutate(
    parallel = TRUE,
    run = rand_int,
    num_workers = parallelly::availableCores(),
    framework = "foreach",
    backend = "multisession",
    platform = .Platform$pkgType,
    rel_time = as.numeric(time),
    rel_time = (rel_time - min(rel_time)) / (max(rel_time) - min(rel_time))
  )

# ------------------------------------------------------------------------------

save(res, file = file.path("results", paste0("res", suffix)))
save(monitor, main_pid, file = file.path("results", paste0("monitor", suffix)))

# ------------------------------------------------------------------------------

stopCluster(cl)

if (!interactive()) {
  q("no")
}
