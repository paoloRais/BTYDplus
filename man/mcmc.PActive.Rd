% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/mcmc.R
\name{mcmc.PActive}
\alias{mcmc.PActive}
\title{Calculates P(active) based on drawn future transactions.}
\usage{
mcmc.PActive(xstar)
}
\arguments{
\item{xstar}{Future transaction draws as returned by
\code{\link{mcmc.DrawFutureTransactions}}.}
}
\value{
numeric A vector with the customers' probabilities of being active
  during the holdout period.
}
\description{
Calculates P(active) based on drawn future transactions.
}
\examples{
data("groceryElog")
cbs <- elog2cbs(groceryElog, T.cal = "2006-12-31")
param.draws <- pnbd.mcmc.DrawParameters(cbs,
  mcmc = 200, burnin = 100, thin = 20, chains = 1) # short MCMC to run demo fast
xstar.draws <- mcmc.DrawFutureTransactions(cbs, param.draws)
cbs$pactive <- mcmc.PActive(xstar.draws)
head(cbs)
}

