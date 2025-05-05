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

all_res <- map_dfr(res_rd, get_res)
all_monitor <- map_dfr(mon_rd, get_monitor)

# ------------------------------------------------------------------------------

all_res |>
  ggplot(aes(parallel, elapsed, group = framework, col = framework)) +
  geom_point(cex = 1) +
  geom_smooth(aes(col = framework), method = lm, se = FALSE) +
  facet_grid(platform~backend)

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
  geom_jitter(width = 0.05) + 
  facet_wrap(~ platform) +
  geom_hline(yintercept = 0, lty = 2, col = "red")

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

all_monitor |>
  filter(
    framework == "foreach/doFuture/%dopar%" &
      parallel &
      pid != main_pid &
      platform == "win.binary"
  ) |>
  slice_min(run, n = 1) |>
  mutate(pid = factor(pid)) |>
  ggplot(aes(time, pct_cpu)) +
  geom_point(aes(col = pid, group = pid), show.legend = FALSE, cex = 1 / 2) +
  geom_line(aes(col = pid, group = pid), show.legend = FALSE) +
  facet_wrap(~pid) +
  labs(title = "foreach + doFuture + multisession + %dopar%")


all_monitor |>
  filter(
    backend == "mirai" & framework == "foreach" & parallel & pid != main_pid
  ) |>
  slice_min(run, n = 1) |>
  mutate(pid = factor(pid)) |>
  ggplot(aes(time, pct_cpu)) +
  geom_point(aes(col = pid, group = pid), show.legend = FALSE, cex = 1 / 2) +
  geom_line(aes(col = pid, group = pid), show.legend = FALSE) +
  facet_wrap(~pid) +
  labs(title = "foreach + mirai")

all_monitor |>
  filter(
    backend == "mirai" & framework == "future" & parallel & pid != main_pid
  ) |>
  slice_min(run, n = 1) |>
  mutate(pid = factor(pid)) |>
  ggplot(aes(time, pct_cpu)) +
  geom_point(aes(col = pid, group = pid), show.legend = FALSE, cex = 1 / 2) +
  geom_line(aes(col = pid, group = pid), show.legend = FALSE) +
  labs(title = "future + mirai") +
  facet_wrap(~pid)


all_monitor |>
  filter(
    backend == "multisession" &
      framework == "future" &
      parallel &
      pid != main_pid
  ) |>
  slice_min(run, n = 1) |>
  mutate(pid = factor(pid)) |>
  ggplot(aes(time, pct_cpu)) +
  geom_point(aes(col = pid, group = pid), show.legend = FALSE, cex = 1 / 2) +
  geom_line(aes(col = pid, group = pid), show.legend = FALSE) +
  labs(title = "future + multisession") +
  facet_wrap(~pid)
