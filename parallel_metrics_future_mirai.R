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
    framework = "future",
    backend = "mirai",
    platform = .Platform$pkgType
  )

# ------------------------------------------------------------------------------

library(parallelly)
library(future.apply)
library(future.mirai)

plan(mirai_multisession)

suffix <- paste0("-future-mirai-", rand_int, ".RData")

# ------------------------------------------------------------------------------

par_time <-
  system.time({
    set.seed(3)
    metrics <- future_lapply(
      rs$splits,
      compute_metrics,
      future.packages = pkgs,
      future.globals = c("compute_metrics")
    )
  })

par_time

par_time <- tibble::as_tibble_row(par_time) |>
  mutate(
    parallel = TRUE,
    run = rand_int,
    num_workers = parallelly::availableCores(),
    framework = "future",
    backend = "mirai",
    platform = .Platform$pkgType
  )

res <- bind_rows(seq_time, par_time)

# ------------------------------------------------------------------------------

main_pid <- Sys.getpid()

monitor <- syrup({
  set.seed(3)
  metrics <- future_lapply(
    rs$splits,
    compute_metrics,
    future.packages = pkgs,
    future.globals = c("compute_metrics")
  )
}, interval = 1 / 20)

monitor <- monitor |>
  mutate(
    parallel = TRUE,
    run = rand_int,
    num_workers = parallelly::availableCores(),
    framework = "future",
    backend = "mirai",
    platform = .Platform$pkgType,
    rel_time = as.numeric(time),
    rel_time = (rel_time - min(rel_time)) / (max(rel_time) - min(rel_time))
  )

# ------------------------------------------------------------------------------

save(res, file = file.path("results", paste0("res", suffix)))
save(monitor, main_pid, file = file.path("results", paste0("monitor", suffix)))

# ------------------------------------------------------------------------------

if (!interactive()) {
  q("no")
}
