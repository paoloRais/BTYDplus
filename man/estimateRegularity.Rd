% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/helpers.R
\name{estimateRegularity}
\alias{estimateRegularity}
\title{Estimate Regularity in Intertransaction Timings}
\usage{
estimateRegularity(elog, method = "wheat", plot = FALSE, title = "",
  min = NULL)
}
\arguments{
\item{elog}{Event log, a \code{data.frame} with columns \code{cust} and
transaction time \code{t} or \code{date}}

\item{method}{Either \code{wheat}, \code{mle}, \code{mle-minka}, \code{mle-thom} or
\code{cv}.}

\item{plot}{If \code{TRUE} then an additional diagnostic plot is provided.}

\item{title}{Plot title.}

\item{min}{Minimum number of intertransaction times per customer. Customers
with less than \code{min} intertransactions are not considered. Defaults to 2
for method `wheat`, and to 10 otherwise.}
}
\value{
Estimated real-valued regularity parameter.
}
\description{
The models (M)BG/CNBD-k and Pareto/GGG are capable of leveraging regularity
within transaction timings for improving forecast accuracy. This method
provides a quick check for the degree of regularity in the event timings. A
return value of close to 1 supports the assumption of exponentially
distributed intertransaction times, whereas values significantly larger than
1 reveal the presence of regularity.
}
\details{
Estimation is either done by 1) assuming the same degree of regularity across
all customers (Wheat & Morrison (1990) via \code{method = "wheat"}), or 2) by
estimating regularity for each customer separately, as the shape parameter of
a fitted gamma distribution, and then return the median across estimates. The
latter methods, though, require sufficient (>=\code{min}) transactions per
customer.

Wheat & Morrison (1990)'s method calculates for each customer a statistic
\code{M} based on her last two number of intertransaction times as
\code{ITT_1 / (ITT_1 + ITT_2)}. That measure is known to follow a
\code{Beta(k, k)} distribution, and \code{k} can be estimated as
\code{(1-4*Var(M))/(8*Var(M))}. The corresponding diagnostic plot (\code{plot
= TRUE}) shows the actual distribution of \code{M} vs. the theoretical
distribution for \code{k = 1} and \code{k = 2}.
}
\examples{
data("groceryElog")
estimateRegularity(groceryElog, plot = TRUE, method = 'wheat')
estimateRegularity(groceryElog, plot = TRUE, method = 'mle-minka')
estimateRegularity(groceryElog, plot = TRUE, method = 'mle-thom')
estimateRegularity(groceryElog, plot = TRUE, method = 'cv')
}
\references{
Wheat, Rita D., and Donald G. Morrison. "Estimating purchase
  regularity with two interpurchase times." Journal of Marketing Research
  (1990): 87-93.

Dunn, Richard, Steven Reader, and Neil Wrigley. 'An investigation
  of the assumptions of the NBD model' Applied Statistics (1983): 249-259.

Wu, Couchen, and H-L. Chen. 'A consumer purchasing model with
  learning and departure behaviour.'  Journal of the Operational Research
  Society (2000): 583-591.

\url{http://research.microsoft.com/en-us/um/people/minka/papers/minka-gamma.pdf}
}

