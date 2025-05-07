library(dplyr)
library(ggplot2)
library(purrr)

theme_set(theme_bw())
options(pillar.advice = FALSE, pillar.min_title_chars = Inf)

# ------------------------------------------------------------------------------

res_rd <- list.files("results", pattern = "res-", full.names = TRUE)
mon_rd <- list.files("results", pattern = "monitor-", full.names = TRUE)

# ------------------------------------------------------------------------------

get_res <- function(x) {
  load(x)
  res |>
    mutate(
      backend = ifelse(backend == "foreach", "multisession", backend)
    )
}

get_monitor <- function(x) {
  load(x)
  monitor |>
    filter(!is.na(pct_cpu)) |>
    mutate(main_pid = main_pid)
}

# ------------------------------------------------------------------------------

all_res <- map_dfr(res_rd, get_res) |>
  mutate(
    platform = if_else(platform == "source", "unix", platform),
    platform = if_else(
      platform == "mac.binary.big-sur-arm64",
      "macOS",
      platform
    )
  )
all_res |> count(platform, framework, backend)

num_workers <- all_res |> distinct(platform, framework, backend, num_workers)

all_monitor <- map_dfr(mon_rd, get_monitor) |>
  mutate(
    platform = if_else(platform == "source", "unix", platform),
    platform = if_else(
      platform == "mac.binary.big-sur-arm64",
      "macOS",
      platform
    )
  )
all_monitor |> count(platform, framework, backend)

# ------------------------------------------------------------------------------

all_res |>
  ggplot(aes(parallel, elapsed, group = framework, col = framework)) +
  geom_point(cex = 1) +
  geom_smooth(aes(col = framework), method = lm, se = FALSE) +
  facet_grid(backend ~ platform) +
  labs(y = "Execution Time") + 
  theme(legend.position = "top")

baseline <-
  all_res |>
  filter(!parallel) |>
  select(baseline = elapsed, run, framework, backend, platform)

speed_ups <-
  all_res |>
  filter(parallel) |>
  inner_join(baseline, by = join_by(run, framework, backend, platform)) |>
  mutate(speed_up = as.numeric(baseline / elapsed))

speed_ups |>
  ggplot(aes(backend, speed_up, col = framework)) +
  geom_jitter(width = 0.05, alpha = 1 / 2) +
  facet_wrap(~platform) +
  geom_hline(yintercept = 1, lty = 2, col = "red") +
  geom_hline(
    data = num_workers,
    aes(yintercept = num_workers),
    lty = 2,
    col = "green"
  ) +
  scale_y_continuous(trans = "log2") +
  labs(y = "Speed-Up") + 
  theme(legend.position = "top")

# ------------------------------------------------------------------------------

total_cpu <-
  all_monitor |>
  summarize(
    max_cpu = max(pct_cpu),
    min_cpu = min(pct_cpu),
    .by = c(run, pid, framework, backend)
  ) |>
  filter(max_cpu > 250 | max_cpu < 1) |>
  select(-max_cpu, -min_cpu)

monitor_plot <- function(x, .platform, .backend, .framework) {
  plot_data <- x |>
    filter(
      framework == .framework &
        backend == .backend &
        parallel &
        pid != main_pid &
        platform %in% .platform
    ) |>
    slice_min(run, n = 1) |>
    mutate(
      pid = factor(pid),
      worker = format(as.integer(pid)),
      worker = paste("worker process", worker)
      )
  
  total_time <- 
    difftime(
      max(plot_data$time),
      min(plot_data$time),
      units = "secs"
    ) |> 
    ceiling()
  
  x_lab <- paste0("Time (min:sec)\ntotal time: ", as.numeric(total_time), "s")
  titl <- paste0(.framework, " via ", .backend, " (", .platform, ")")
  
  plot_data |>
    ggplot(aes(time, pct_cpu)) +
    geom_point(
      aes(col = worker, group = worker),
      show.legend = FALSE,
      cex = 1 / 2
    ) +
    geom_line(aes(col = worker, group = worker), show.legend = FALSE) +
    facet_wrap(~worker) +
    scale_x_datetime(date_labels = "%M:%S") +
    labs(
      title = titl,
      x = x_lab,
      y = "CPU usage (%)"
    )
}

monitor_plot(
  all_monitor,
  .framework = "future",
  .backend = "mirai",
  .platform = "unix"
)
monitor_plot(
  all_monitor,
  .framework = "future",
  .backend = "mirai",
  .platform = "macOS"
)
monitor_plot(
  all_monitor,
  .framework = "future",
  .backend = "multisession",
  .platform = "unix"
)
