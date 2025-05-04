#!/bin/zsh

R CMD BATCH --vanilla parallel_metrics_future_multisession.R
sleep 10
R CMD BATCH --vanilla parallel_metrics_foreach_mirai.R
sleep 10
R CMD BATCH --vanilla parallel_metrics_foreach_doFuture.R
sleep 10
R CMD BATCH --vanilla parallel_metrics_future_mirai.R
sleep 10
R CMD BATCH --vanilla parallel_metrics_foreach_only.R

# batch 2

sleep 10

R CMD BATCH --vanilla parallel_metrics_foreach_mirai.R
sleep 10
R CMD BATCH --vanilla parallel_metrics_future_multisession.R
sleep 10
R CMD BATCH --vanilla parallel_metrics_foreach_doFuture.R
sleep 10
R CMD BATCH --vanilla parallel_metrics_future_mirai.R
sleep 10
R CMD BATCH --vanilla parallel_metrics_foreach_only.R

# batch 3

sleep 10

R CMD BATCH --vanilla parallel_metrics_future_mirai.R
sleep 10
R CMD BATCH --vanilla parallel_metrics_foreach_doFuture.R
sleep 10
R CMD BATCH --vanilla parallel_metrics_future_multisession.R
sleep 10
R CMD BATCH --vanilla parallel_metrics_foreach_only.R
sleep 10
R CMD BATCH --vanilla parallel_metrics_foreach_mirai.R


# batch 4

sleep 10

R CMD BATCH --vanilla parallel_metrics_future_multisession.R
sleep 10
R CMD BATCH --vanilla parallel_metrics_foreach_only.R
sleep 10
R CMD BATCH --vanilla parallel_metrics_foreach_mirai.R
sleep 10
R CMD BATCH --vanilla parallel_metrics_future_mirai.R
sleep 10
R CMD BATCH --vanilla parallel_metrics_foreach_doFuture.R

# batch 5

sleep 10

R CMD BATCH --vanilla parallel_metrics_foreach_only.R
sleep 10
R CMD BATCH --vanilla parallel_metrics_foreach_mirai.R
sleep 10
R CMD BATCH --vanilla parallel_metrics_foreach_doFuture.R
sleep 10
R CMD BATCH --vanilla parallel_metrics_future_mirai.R
sleep 10
R CMD BATCH --vanilla parallel_metrics_future_multisession.R

