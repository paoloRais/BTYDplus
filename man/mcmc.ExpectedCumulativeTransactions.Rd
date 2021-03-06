% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/mcmc.R
\name{mcmc.ExpectedCumulativeTransactions}
\alias{mcmc.ExpectedCumulativeTransactions}
\title{Expected Cumulative Transactions for Pareto/GGG, Pareto/NBD (HB) and
Pareto/NBD (Abe)}
\usage{
mcmc.ExpectedCumulativeTransactions(draws, T.cal, T.tot, n.periods.final,
  sample_size = 10000)
}
\arguments{
\item{draws}{MCMC draws as returned by \code{*.mcmc.DrawParameters}}

\item{T.cal}{A vector to represent customers' calibration period lengths (in
other words, the \code{T.cal} column from a
customer-by-sufficient-statistic matrix). Considering rounding in order to
speed up calculations.}

\item{T.tot}{End of holdout period. Must be a single value, not a vector.}

\item{n.periods.final}{Number of time periods in the calibration and holdout
periods.}

\item{sample_size}{Sample size for estimating the probability distribution.}
}
\value{
Numeric vector of expected cumulative total repeat transactions by
  all customers.
}
\description{
Uses model parameter draws to return the expected number of repeat
transactions that a randomly chosen customer (for whom we have no prior
information) is expected to make in a given time period.
}
\details{
The expected transactions need to be sampled. Due to this sampling, the
return result varies from one call to another. Larger values of
\code{sample_size} will generate more stable results.
}
\examples{
data("groceryElog")
cbs <- elog2cbs(groceryElog)
param.draws <- pnbd.mcmc.DrawParameters(cbs,
  mcmc = 200, burnin = 100, thin = 20, chains = 1) # short MCMC to run demo fast
# Returns a vector containing expected cumulative repeat transactions for 104
# weeks, with every eigth week being reported.
mcmc.ExpectedCumulativeTransactions(param.draws,
  T.cal = cbs$T.cal, T.tot = 104, n.periods.final = 104/8, sample_size = 1000)
}

