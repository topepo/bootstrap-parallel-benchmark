# Parallel Processing Bootstrap Samples

The tidymodels group is completing its transition from using the foreach package for parallel processing, moving to the future framework. 
 
I was working on doing this for our infrastructure in the tune package to conduct bootstrap confidence intervals for model performance statistics (e.g., area under the ROC curve, R<sup>2</sup>, etc). 
 
When running test cases, I noticed that parallel processing was taking longer than sequential execution. This is expected for tasks that are already very fast. However, in this application, I was splitting 30,000 tasks across 10 workers, so I was expecting, at worst, to break even in terms of execution time. 
 
While looking at the macOS Activity Monitor, no more than 2-3 workers were doing anything at any specific time, and the utilization seemed to be hopping around between worker processes a lot. To quantify/check this, I used Simon’s syrup port and found that there was a saw-toothed pattern to the percent CPU data: 
 

## Reprex

We need a _small_ reproducible example to test with, so I simplified the task so that we didn’t need all of the tidymodels infrastructure. For these tests, I simulate 10,000 data points of observed and predicted values, then compute four performance statistics using the yardstick package. 
 
The original problems differ slightly from this since we compute metrics for different model candidates within each data set; basically, the original code has a short `for` loop inside of it.

 There are five R scripts that run the benchmarks under different scenarios. The foreach cases are used as a control. Each run of the scripts produces a baseline sequential result that uses `lapply()`. Each as run five times in a stratified random order
 
### `parallel_metrics_foreach_only.R`
 
 Runs foreach using a psock cluster. Pseudocode:
 
```r
foreach(i = boot_size, .packages = pkgs) %dopar%
  compute_metrics(rsamples)
``` 
 
### `parallel_metrics_foreach_mirai.R`

  Runs foreach using a mirai cluster (via `mirai:: make_cluster()`). Pseudocode is the same
 
```r
foreach(i = boot_size, .packages = pkgs) %dopar%
  compute_metrics(rsamples)
``` 
 
### `parallel_metrics_foreach_doFuture.R`
 
 Use the doFuture package to setup the multisession (=psock) workers and still be the standard foreach operator 
 
 ```r
registerDoFuture()
plan(multisession)

foreach(i = boot_size, .packages = pkgs) %dopar%
  compute_metrics(rsamples)
``` 

### `parallel_metrics_future_multisession.R`

Basic future code (via future.apply) using a multisession plan: 

 ```r
plan(multisession)

future_lapply(
    resamples,
    compute_metrics,
    future.packages = c("rsample", "yardstick"),
    future.globals = c("compute_metrics")
  )
``` 

### `parallel_metrics_future_mirai.R`

Same but using mirai directly via future.mirai:

 ```r
plan(mirai_multisession)

future_lapply(
    resamples,
    compute_metrics,
    future.packages = c("rsample", "yardstick"),
    future.globals = c("compute_metrics")
  )
``` 

## Running the Tests

There are a few packages to install: 


``` r
pkgs <- c("doFuture", "doParallel", "dplyr", "foreach", "future.mirai", 
          "future.apply", "ggplot2", "mirai", "parallelly", "purrr", "rsample", 
          "sessioninfo", "simonpcouch/syrup", "yardstick")
```

We recommend using the pak package to install them: 

```r
pak::pak(pkgs, ask = FALSE)
```

To produce the results, run `go.sh` in a terminal from the root of this repository and more results are generated. You will not get the same numbers as those shown here. Using an Apple M3 Pro MacBook Pro, the script takes about 25 minutes to run. 

## Results



Unlike the original task, the results show that parallel processing is speeding things up to various degrees. The fastest was using foreach with doFuture (more on this below). On average, mirai was faster than multisession, most likely because its allocation of tasks to workers is dynamic. 


<div class="figure" style="text-align: center">
<img src="figure/timings-1.svg" alt="plot of chunk timings" width="70%" />
</div>

When viewed as speed-ups:

<div class="figure" style="text-align: center">
<img src="figure/speedups-1.svg" alt="plot of chunk speedups" width="70%" />
</div>

The best speed-ups were around 7.5-fold. This is good but should probably be higher since 12 cores were used in parallel. The other combinations ranged between 1.5-fold to about 3-fold. 

## CPU Itilization

CPU usage was recorded for the workers every 0.05 seconds. We can see how each case behaved. In the plots below, each facet is a worker process (the value in the banner is the process ID).

First, the winner: foreach with doFuture has the best speed-ups but from the CPU data, this is inexpiable since only one worker appears to be doing anything (this is consistent across the five runs): 

<div class="figure" style="text-align: center">
<img src="figure/foreach-future-1.svg" alt="plot of chunk foreach-future" width="100%" />
</div>


¯\\_(ツ)_/¯

mirai (with foreach) was trying harder to maintain utilization, but it significantly fluctuates with periods of inactivity.  

<div class="figure" style="text-align: center">
<img src="figure/foreach-mirai-1.svg" alt="plot of chunk foreach-mirai" width="100%" />
</div>

Switching to using mirai with future showd utilization ramping up but, overall, has speed-ups less than 3-fold using 12 workers. 

<div class="figure" style="text-align: center">
<img src="figure/future-mirai-1.svg" alt="plot of chunk future-mirai" width="100%" />
</div>

Finally, future and multisession showed a pattern that approximated our original results. 

<div class="figure" style="text-align: center">
<img src="figure/future-multisession-1.svg" alt="plot of chunk future-multisession" width="100%" />
</div>


## Session Info



The versions that I had when running these: 


```
## ─ Session info ───────────────────────────────────────────────────────────────────────────────────────────────────────
##  setting  value
##  version  R version 4.5.0 (2025-04-11)
##  os       macOS Sequoia 15.4.1
##  system   aarch64, darwin20
##  ui       X11
##  language (EN)
##  collate  en_US.UTF-8
##  ctype    en_US.UTF-8
##  tz       America/New_York
##  date     2025-05-04
##  pandoc   3.1.11 @ /opt/homebrew/bin/pandoc
##  quarto   1.7.27 @ /usr/local/bin/quarto
## 
## ─ Packages ───────────────────────────────────────────────────────────────────────────────────────────────────────────
##  package      * version    date (UTC) lib source
##  bench        * 1.1.4      2025-01-16 [1] RSPM
##  callr          3.7.6      2024-03-25 [1] RSPM
##  cli            3.6.4      2025-02-13 [1] RSPM (R 4.5.0)
##  codetools      0.2-20     2024-03-31 [2] CRAN (R 4.5.0)
##  cpp11          0.5.1      2024-12-04 [1] RSPM
##  digest         0.6.37     2024-08-19 [1] RSPM
##  doFuture     * 1.0.2      2025-03-16 [1] RSPM
##  doParallel   * 1.0.17     2022-02-07 [1] RSPM
##  dplyr        * 1.1.4      2023-11-17 [1] CRAN (R 4.5.0)
##  fansi          1.0.6      2023-12-08 [1] RSPM
##  farver         2.1.2      2024-05-13 [1] RSPM
##  foreach      * 1.5.2      2022-02-02 [1] RSPM
##  furrr          0.3.1      2022-08-15 [1] RSPM
##  future       * 1.40.0     2025-04-10 [1] RSPM
##  future.apply * 1.11.3     2024-10-27 [1] CRAN (R 4.5.0)
##  future.mirai * 0.2.2      2024-07-03 [1] CRAN (R 4.5.0)
##  generics       0.1.3      2022-07-05 [1] RSPM
##  ggplot2      * 3.5.2      2025-04-09 [1] CRAN (R 4.5.0)
##  globals        0.17.0     2025-04-16 [1] CRAN (R 4.5.0)
##  glue           1.8.0      2024-09-30 [1] RSPM (R 4.5.0)
##  gtable         0.3.6      2024-10-25 [1] RSPM
##  hardhat        1.4.1      2025-01-31 [1] CRAN (R 4.5.0)
##  isoband        0.2.7      2022-12-20 [1] RSPM
##  iterators    * 1.0.14     2022-02-05 [1] RSPM
##  labeling       0.4.3      2023-08-29 [1] RSPM
##  lattice        0.22-7     2025-04-02 [1] RSPM
##  lifecycle      1.0.4      2023-11-07 [1] RSPM (R 4.5.0)
##  listenv        0.9.1      2024-01-29 [1] RSPM
##  magrittr       2.0.3      2022-03-30 [1] RSPM (R 4.5.0)
##  MASS           7.3-65     2025-02-28 [2] CRAN (R 4.5.0)
##  Matrix         1.7-3      2025-03-11 [2] CRAN (R 4.5.0)
##  mgcv           1.9-3      2025-04-04 [1] RSPM
##  mirai        * 2.2.0      2025-03-20 [1] CRAN (R 4.5.0)
##  nanonext       1.5.2      2025-03-18 [1] CRAN (R 4.5.0)
##  nlme           3.1-168    2025-03-31 [2] CRAN (R 4.5.0)
##  parallelly   * 1.43.0     2025-03-24 [1] RSPM
##  pillar         1.10.2     2025-04-05 [1] RSPM
##  pkgconfig      2.0.3      2019-09-22 [1] RSPM
##  processx       3.8.6      2025-02-21 [1] RSPM
##  profmem        0.6.0      2020-12-13 [1] RSPM
##  ps             1.9.1      2025-04-12 [1] RSPM
##  purrr        * 1.0.4      2025-02-05 [1] CRAN (R 4.5.0)
##  R6             2.6.1      2025-02-15 [1] CRAN (R 4.5.0)
##  RColorBrewer   1.1-3      2022-04-03 [1] RSPM
##  rlang          1.1.6      2025-04-11 [1] RSPM (R 4.5.0)
##  rsample      * 1.3.0      2025-04-02 [1] CRAN (R 4.5.0)
##  scales         1.4.0      2025-04-24 [1] CRAN (R 4.5.0)
##  sessioninfo  * 1.2.3      2025-02-05 [1] RSPM
##  slider         0.3.2      2024-10-25 [1] RSPM
##  sparsevctrs    0.3.3      2025-04-14 [1] CRAN (R 4.5.0)
##  stringi        1.8.7      2025-03-27 [1] RSPM
##  stringr        1.5.1      2023-11-14 [1] RSPM
##  syrup        * 0.1.3.9000 2025-05-01 [1] Github (simonpcouch/syrup@6720ecd)
##  tibble         3.2.1      2023-03-20 [1] CRAN (R 4.5.0)
##  tidyr          1.3.1      2024-01-24 [1] CRAN (R 4.5.0)
##  tidyselect     1.2.1      2024-03-11 [1] RSPM
##  utf8           1.2.4      2023-10-22 [1] RSPM
##  vctrs          0.6.5      2023-12-01 [1] RSPM (R 4.5.0)
##  viridisLite    0.4.2      2023-05-02 [1] RSPM
##  warp           0.2.1      2023-11-02 [1] RSPM
##  withr          3.0.2      2024-10-28 [1] RSPM
##  yardstick    * 1.3.2      2025-01-22 [1] CRAN (R 4.5.0)
## 
##  [1] /Users/max/Library/R/arm64/4.5/library
##  [2] /Library/Frameworks/R.framework/Versions/4.5-arm64/Resources/library
##  * ── Packages attached to the search path.
## 
## ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
```
