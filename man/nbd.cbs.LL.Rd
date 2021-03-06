% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/nbd.R
\name{nbd.cbs.LL}
\alias{nbd.cbs.LL}
\title{Calculate the log-likelihood of the NBD model}
\usage{
nbd.cbs.LL(params, cal.cbs)
}
\arguments{
\item{params}{NBD parameters - a vector with r and alpha, in that
order.}

\item{cal.cbs}{Calibration period CBS. It must contain columns for frequency
\code{x} and total time observed \code{T.cal}.}
}
\value{
The total log-likelihood for the provided data.
}
\description{
Calculate the log-likelihood of the NBD model
}
\examples{
data("groceryElog")
cbs <- elog2cbs(groceryElog)
params <- nbd.EstimateParameters(cbs)
nbd.cbs.LL(params, cbs)
}

