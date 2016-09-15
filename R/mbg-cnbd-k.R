
#' (M)BG/CNBD-k Parameter Estimation
#' 
#' Estimates parameters for the (M)BG/CNBD-k model via Maximum Likelihood
#' Estimation.
#' 
#' @param cal.cbs Calibration period customer-by-sufficient-statistic (CBS) 
#'   data.frame. It must contain a row for each customer, and columns \code{x} 
#'   for frequency, \code{t.x} for recency , \code{T.cal} for the total time 
#'   observed, as well as the sum over logarithmic intertransaction times 
#'   \code{litt}, in case that \code{k} is not provided. A correct format can be
#'   easily generated based on the complete event log of a customer cohort with 
#'   \code{\link{elog2cbs}}.
#' @param k Integer-valued degree of regularity for Erlang-k distributed 
#'   interpurchase times. By default this \code{k} is not provdied, and a grid 
#'   search from 1 to 12 is performed in order to determine the best-fitting 
#'   \code{k}. The grid search is stopped early, if the log-likelihood doesn't
#'   increase anymore when increasing k beyond 4.
#' @param par.start Initial (M)BG/CNBD-k parameters. A vector with \code{r}, 
#'   \code{alpha}, \code{a} and \code{b} in that order.
#' @param max.param.value Upper bound on parameters.
#' @param trace If larger than 0, then the parameter values are is printed every 
#'   \code{trace}-step of the maximum likelihood estimation search.
#' @return A vector of estimated parameters.
#' @export
#' @seealso \code{\link[BTYD]{bgnbd.EstimateParameters}}
#' @references (M)BG/CNBD-k: Platzer Michael, and Thomas Reutterer (forthcoming)
#' @references MBG/NBD: Batislam, E.P., M. Denizel, A. Filiztekin. 2007.
#'   Empirical validation and comparison of models for customer base analysis.
#'   International Journal of Research in Marketing 24(3) 201–209.
#' @examples
#' cbs <- cdnow.sample()$cbs
#' (params <- mbgcnbd.EstimateParameters(cbs))
#' @export
mbgcnbd.EstimateParameters <- function(cal.cbs, k = NULL, 
                                       par.start = c(1, 3, 1, 3), max.param.value = 10000, 
                                       trace = 0) {
  xbgcnbd.EstimateParameters(cal.cbs, k = k,
                             par.start = par.start, max.param.value = max.param.value, 
                             trace = trace, dropout_at_zero = TRUE)
}

#' @rdname mbgcnbd.EstimateParameters
#' @export
bgcnbd.EstimateParameters <- function(cal.cbs, k = NULL, 
                                      par.start = c(1, 3, 1, 3), max.param.value = 10000, 
                                      trace = 0) {
  xbgcnbd.EstimateParameters(cal.cbs, k = k,
                             par.start = par.start, max.param.value = max.param.value, 
                             trace = trace, dropout_at_zero = FALSE)
}

#' @rdname mbgcnbd.EstimateParameters
#' @export
mbgnbd.EstimateParameters <- function(cal.cbs,
                                      par.start = c(1, 3, 1, 3), max.param.value = 10000, 
                                      trace = 0) {
  xbgcnbd.EstimateParameters(cal.cbs, k = 1,
                             par.start = par.start, max.param.value = max.param.value, 
                             trace = trace, dropout_at_zero = TRUE)
}

#' @keywords internal
xbgcnbd.EstimateParameters <- function(cal.cbs, k = NULL, 
                                       par.start = c(1, 3, 1, 3), max.param.value = 10000, 
                                       trace = 0, dropout_at_zero = NULL) {
  stopifnot(!is.null(dropout_at_zero))
  dc.check.model.params.safe(c("r", "alpha", "a", "b"), par.start, "xbgcnbd.EstimateParameters")
  
  # either `k` or `litt` need to be present
  if (is.null(k) & !"litt" %in% colnames(cal.cbs))
    stop("Either regularity parameter k need to be specified, or a column with logarithmic interpurchase times litt need to be present in cal.cbs")
  
  # if `k` is not specified we do grid search for `k`
  if (is.null(k)) {
    params <- list()
    LL <- c()
    for (k in 1:12) {
      params[[k]] <- tryCatch(xbgcnbd.EstimateParameters(cal.cbs = cal.cbs, k = k, par.start = par.start, max.param.value = max.param.value, 
                                                         trace = trace, dropout_at_zero = dropout_at_zero), error = function(e) {
                                                           e
                                                         })
      if (inherits(params[[k]], "error")) {
        params[[k]] <- NULL
        break  # stop if parameters could not be estimated, e.g. if xbgcnbd.LL returns Inf
      }
      LL[k] <- xbgcnbd.cbs.LL(params = params[[k]], cal.cbs = cal.cbs, dropout_at_zero = dropout_at_zero)
      if (k > 4 && LL[k] < LL[k - 1] && LL[k - 1] < LL[k - 2]) 
        break  # stop if LL gets worse for increasing k
    }
    k <- which.max(LL)
    return(params[[k]])
  }
  
  # if `litt` is missing, we set it to zero, so that xbgcnbd.cbs.LL does not complain; however this makes LL values
  # for different k values not comparable
  if (!"litt" %in% colnames(cal.cbs)) 
    cal.cbs[, "litt"] <- 0
  
  count <- 0
  xbgcnbd.eLL <- function(params, k, cal.cbs, max.param.value, dropout_at_zero) {
    params <- exp(params)
    params[params > max.param.value] <- max.param.value
    params <- c(k, params)
    loglik <- xbgcnbd.cbs.LL(params = params, cal.cbs = cal.cbs, dropout_at_zero = dropout_at_zero)
    count <<- count + 1
    if (trace > 0 & count%%trace == 0) 
      cat("xbgcnbd.EstimateParameters - k:", sprintf("%2.0f", k)," step:", sprintf("%4.0f", count), " - ", sprintf("%12.1f", loglik), ":", sprintf("%10.4f", 
                                                                                                                                                   params), "\n")
    return(-1 * loglik)
  }
  
  logparams <- log(par.start)
  results <- optim(logparams, xbgcnbd.eLL, cal.cbs = cal.cbs, k = k, max.param.value = max.param.value, dropout_at_zero = dropout_at_zero, 
                   method = "L-BFGS-B")
  estimated.params <- exp(results$par)
  estimated.params[estimated.params > max.param.value] <- max.param.value
  estimated.params <- c(k, estimated.params)
  names(estimated.params) <- c("k", "r", "alpha", "a", "b")
  return(estimated.params)
}



#' (M)BG/CNBD-k Log-Likelihood
#' 
#' Calculates the log-likelihood of the (M)BG/CNBD-k model.
#' 
#' @param params A vector with model parameters \code{k}, \code{r}, 
#'   \code{alpha}, \code{a} and \code{b}, in that order.
#' @param cal.cbs Calibration period customer-by-sufficient-statistic (CBS) 
#'   data.frame. It must contain a row for each customer, and columns \code{x} 
#'   for frequency, \code{t.x} for recency , \code{T.cal} for the total time 
#'   observed, as well as the sum over logarithmic intertransaction times 
#'   \code{litt}. A correct format can be easily generated based on the complete
#'   event log of a customer cohort with \code{\link{elog2cbs}}.
#' @param x frequency, i.e. number of re-purchases
#' @param t.x recency, i.e. time elapsed from first purchase to last purchase
#' @param T.cal total time of observation period
#' @param litt sum of logarithmic interpurchase times
#' @return For \code{bgcnbd.cbs.LL}, the total log-likelihood of the provided
#'   data. For \code{bgcnbd.LL}, a vector of log-likelihoods as long as the
#'   longest input vector (\code{x}, \code{t.x}, or \code{T.cal}).
#' @references Platzer Michael, and Thomas Reutterer (forthcoming)
#' @export
mbgcnbd.cbs.LL <- function(params, cal.cbs) {
  xbgcnbd.cbs.LL(params, cal.cbs, dropout_at_zero = TRUE)
}

#' @rdname mbgcnbd.cbs.LL
#' @export
mbgcnbd.LL <- function(params, x, t.x, T.cal, litt) {
  xbgcnbd.LL(params, x, t.x, T.cal, litt, dropout_at_zero = TRUE)
}

#' @rdname mbgcnbd.cbs.LL
#' @export
bgcnbd.cbs.LL <- function(params, cal.cbs) {
  xbgcnbd.cbs.LL(params, cal.cbs, dropout_at_zero = FALSE)
}

#' @rdname mbgcnbd.cbs.LL
#' @export
bgcnbd.LL <- function(params, x, t.x, T.cal, litt) {
  xbgcnbd.LL(params, x, t.x, T.cal, litt, dropout_at_zero = FALSE)
}

#' @keywords internal
xbgcnbd.cbs.LL <- function(params, cal.cbs, dropout_at_zero = NULL) {
  stopifnot(!is.null(dropout_at_zero))
  dc.check.model.params.safe(c("k", "r", "alpha", "a", "b"), params, "xbgcnbd.cbs.LL")
  tryCatch(x <- cal.cbs$x, error = function(e) stop("Error in xbgcnbd.cbs.LL: cal.cbs must have a frequency column labelled \"x\""))
  tryCatch(t.x <- cal.cbs$t.x, error = function(e) stop("Error in xbgcnbd.cbs.LL: cal.cbs must have a recency column labelled \"t.x\""))
  tryCatch(T.cal <- cal.cbs$T.cal, error = function(e) stop("Error in xbgcnbd.cbs.LL: cal.cbs must have a column for length of time observed labelled \"T.cal\""))
  tryCatch(litt <- cal.cbs$litt, error = function(e) stop("Error in xbgcnbd.cbs.LL: cal.cbs must have a column for sum over logarithmic inter-transaction-times labelled \"litt\""))
  if ("custs" %in% colnames(cal.cbs)) {
    custs <- cal.cbs$custs
  } else {
    custs <- rep(1, length(x))
  }
  return(sum(custs * xbgcnbd.LL(params = params, x = x, t.x = t.x, T.cal = T.cal, litt = litt, dropout_at_zero = dropout_at_zero)))
}

#' @keywords internal
xbgcnbd.LL <- function(params, x, t.x, T.cal, litt, dropout_at_zero = NULL) {
  stopifnot(!is.null(dropout_at_zero))
  max.length <- max(length(x), length(t.x), length(T.cal))
  if (max.length%%length(x)) 
    warning("Maximum vector length not a multiple of the length of x")
  if (max.length%%length(t.x)) 
    warning("Maximum vector length not a multiple of the length of t.x")
  if (max.length%%length(T.cal)) 
    warning("Maximum vector length not a multiple of the length of T.cal")
  if (max.length%%length(litt)) 
    warning("Maximum vector length not a multiple of the length of litt")
  dc.check.model.params.safe(c("k", "r", "alpha", "a", "b"), params, "xbgcnbd.LL")
  if (params[1] != floor(params[1]) | params[1] < 1) 
    stop("k must be integer being greater or equal to 1.")
  if (any(x < 0) || !is.numeric(x)) 
    stop("x must be numeric and may not contain negative numbers.")
  if (any(t.x < 0) || !is.numeric(t.x)) 
    stop("t.x must be numeric and may not contain negative numbers.")
  if (any(T.cal < 0) || !is.numeric(T.cal)) 
    stop("T.cal must be numeric and may not contain negative numbers.")
  x <- rep(x, length.out = max.length)
  t.x <- rep(t.x, length.out = max.length)
  T.cal <- rep(T.cal, length.out = max.length)
  litt <- rep(litt, length.out = max.length)
  k <- params[1]
  r <- params[2]
  alpha <- params[3]
  a <- params[4]
  b <- params[5]
  P1 <- (k - 1) * litt - x * log(factorial(k - 1))
  P2 <- lbeta(a, b + x + ifelse(dropout_at_zero, 1, 0)) - lbeta(a, b)
  P3 <- lgamma(r + k * x) - lgamma(r) + r * log(alpha)
  P4 <- -1 * (r + k * x) * log(alpha + T.cal)
  S1 <- as.numeric(dropout_at_zero | x > 0) * 
    a/(b + x - 1 + ifelse(dropout_at_zero, 1, 0)) * 
    ((alpha + T.cal)/(alpha + t.x))^(r + k * x)
  S2 <- 1
  if (k > 1) {
    for (j in 1:(k - 1)) {
      S2a <- 1
      for (i in 0:(j - 1)) S2a <- S2a * (r + k * x + i)
      S2 <- S2 + (S2a * (T.cal - t.x)^j)/(factorial(j) * (alpha + T.cal)^j)
    }
  }
  return(P1 + P2 + P3 + P4 + log(S1 + S2))
}



#' (M)BG/CNBD-k Probability Mass Function
#' 
#' Uses (M)BG/CNBD-k model parameters to return the probability distribution of 
#' purchase frequencies for a random customer in a given time period, i.e. 
#' \eqn{P(X(t)=x|r,alpha,a,b)}.
#' 
#' @param params A vector with model parameters \code{k}, \code{r}, 
#'   \code{alpha}, \code{a} and \code{b}, in that order.
#' @param t Length end of time period for which probability is being computed. 
#'   May also be a vector.
#' @param x Number of repeat transactions for which probability is calculated.
#'   May also be a vector.
#' @return \eqn{P(X(t)=x|r,alpha,a,b)}. If either \code{t} or \code{x} is a 
#'   vector, then the output will be a vector as well. If both are vectors, the 
#'   output will be a matrix.
#' @export
#' @references Platzer Michael, and Thomas Reutterer (forthcoming)
#' @examples
#' cbs <- cdnow.sample()$cbs # load CDNow summary data
#' params <- mbgcnbd.EstimateParameters(cbs)
#' mbgcnbd.pmf(params, t = c(26, 52), x = 0:6)
#' mbgcnbd.pmf(params, t = 52, x = 0:6)
mbgcnbd.pmf <- function(params, t, x) {
  xbgcnbd.pmf(params, t, x, dropout_at_zero = TRUE)
}

#' @rdname mbgcnbd.pmf
#' @export
bgcnbd.pmf <- function(params, t, x) {
  xbgcnbd.pmf(params, t, x, dropout_at_zero = FALSE)
}

#' @keywords internal
xbgcnbd.pmf <- function(params, t, x, dropout_at_zero = NULL) {
  stopifnot(!is.null(dropout_at_zero))
  dc.check.model.params.safe(c("k", "r", "alpha", "a", "b"), params, "xbgcnbd.pmf")
  if (params[1] != floor(params[1]) | params[1] < 1) 
    stop("k must be integer being greater or equal to 1.")
  
  pmf <- as.matrix(sapply(t, function(t) {
    sapply(x, function(x) {
      bgcnbd_pmf_cpp(params, t, x, dropout_at_zero) # call fast C++ implementation
    })
  }))
  if (length(x) == 1) pmf <- t(pmf)
  rownames(pmf) <- x
  colnames(pmf) <- t
  drop(pmf)
}



#' (M)BG/CNBD-k Expectation
#' 
#' Returns the number of repeat transactions that a randomly chosen customer
#' (for whom we have no prior information) is expected to make in a given time
#' period, i.e. \eqn{E(X(t) | k, r, alpha, a, b)}.
#' 
#' @param params A vector with model parameters \code{k}, \code{r}, 
#'   \code{alpha}, \code{a} and \code{b}, in that order.
#' @param t Length of time for which we are calculating the expected number of repeat transactions.
#' @return Number of repeat transactions a customer is expected to make in a time period of length t.
#' @export
#' @references Platzer Michael, and Thomas Reutterer (forthcoming)
#' @examples
#' cbs <- cdnow.sample()$cbs # load CDNow summary data
#' params <- mbgcnbd.EstimateParameters(cbs)
#' mbgcnbd.Expectation(params, t = c(26, 52))
mbgcnbd.Expectation <- function(params, t) {
  xbgcnbd.Expectation(params, t, dropout_at_zero = TRUE)
}

#' @rdname mbgcnbd.Expectation
#' @export
bgcnbd.Expectation <- function(params, t) {
  xbgcnbd.Expectation(params, t, dropout_at_zero = FALSE)
}

#' @keywords internal
xbgcnbd.Expectation <- function(params, t, dropout_at_zero = NULL) {
  stopifnot(!is.null(dropout_at_zero))
  dc.check.model.params.safe(c("k", "r", "alpha", "a", "b"), params, "xbgcnbd.Expectation")
  if (any(t < 0) || !is.numeric(t)) 
    stop("t must be numeric and may not contain negative numbers.")
  
  # estimate computation time, and warn if it will take too long
  if (uniqueN(t) > 100) {
    estimated_time <- system.time(xbgcnbd.Expectation(params, max(t), dropout_at_zero))["elapsed"]
    if (uniqueN(t) * estimated_time > 60) {
      cat("note: computation will take long for many unique time values (`t`, `T.cal`, `T.star`,...) - consider rounding!")
    }
  }
  
  # to save computation time, we collapse vector `t` on to its unique values
  ts <- unique(t)
  ts_map <- bgcnbd_exp_cpp(params, ts, dropout_at_zero)
  names(ts_map) <- ts
  res <- (ts_map[as.character(t)])
  return(res)
}



#' (M)BG/CNBD-k P(alive)
#' 
#' Uses (M)BG/CNBD-k model parameters and a customer's past transaction behavior 
#' to return the probability that they are still alive at the end of the 
#' calibration period.
#' 
#' @param params A vector with model parameters \code{k}, \code{r}, 
#'   \code{alpha}, \code{a} and \code{b}, in that order.
#' @param x Number of repeat transactions in the calibration period T.cal, or a 
#'   vector of calibration period frequencies.
#' @param t.x Recency, i.e. length between first and last transaction during 
#'   calibration period.
#' @param T.cal Length of calibration period, or a vector of calibration period 
#'   lengths.
#' @return Probability that the customer is still alive at the end of the 
#'   calibration period.
#' @export
#' @references Platzer Michael, and Thomas Reutterer (forthcoming)
#' @examples
#' cbs <- cdnow.sample()$cbs # load CDNow summary data
#' params <- mbgcnbd.EstimateParameters(cbs)
#' palive <- mbgcnbd.PAlive(params, cbs$x, cbs$t.x, cbs$T.cal)
#' head(palive) # Probability of being alive for first 6 customers
#' mean(palive) # Estimated share of customers to be still alive
mbgcnbd.PAlive <- function(params, x, t.x, T.cal) {
  xbgcnbd.PAlive(params, x, t.x, T.cal, dropout_at_zero = TRUE)
}

#' @rdname mbgcnbd.PAlive
#' @export
bgcnbd.PAlive <- function(params, x, t.x, T.cal) {
  xbgcnbd.PAlive(params, x, t.x, T.cal, dropout_at_zero = FALSE)
}

#' @keywords internal
xbgcnbd.PAlive <- function(params, x, t.x, T.cal, dropout_at_zero = NULL) {
  stopifnot(!is.null(dropout_at_zero))
  max.length <- max(length(x), length(t.x), length(T.cal))
  if (max.length%%length(x)) 
    warning("Maximum vector length not a multiple of the length of x")
  if (max.length%%length(t.x)) 
    warning("Maximum vector length not a multiple of the length of t.x")
  if (max.length%%length(T.cal)) 
    warning("Maximum vector length not a multiple of the length of T.cal")
  dc.check.model.params.safe(c("k", "r", "alpha", "a", "b"), params, "xbgcnbd.PAlive")
  if (params[1] != floor(params[1]) | params[1] < 1) 
    stop("k must be integer being greater or equal to 1.")
  if (any(x < 0) || !is.numeric(x)) 
    stop("x must be numeric and may not contain negative numbers.")
  if (any(t.x < 0) || !is.numeric(t.x)) 
    stop("t.x must be numeric and may not contain negative numbers.")
  if (any(T.cal < 0) || !is.numeric(T.cal)) 
    stop("T.cal must be numeric and may not contain negative numbers.")
  x <- rep(x, length.out = max.length)
  t.x <- rep(t.x, length.out = max.length)
  T.cal <- rep(T.cal, length.out = max.length)
  k <- params[1]
  r <- params[2]
  alpha <- params[3]
  a <- params[4]
  b <- params[5]
  P1 <- (a/(b + x - 1 + ifelse(dropout_at_zero, 1, 0))) * ((alpha + T.cal)/(alpha + t.x))^(r + k * x)
  P2 <- 1
  if (k > 1) {
    for (j in 1:(k - 1)) {
      P2a <- 1
      for (i in 0:(j - 1)) P2a <- P2a * (r + k * x + i)
      P2 <- P2 + ((P2a * (T.cal - t.x)^j)/(factorial(j) * (alpha + T.cal)^j))
    }
  }
  palive <- (1/(1 + P1/P2))
  if (dropout_at_zero == FALSE) 
    palive[x == 0] <- 1
  return(palive)
}


#' (M)BG/CNBD-k Conditional Expected Transactions
#' 
#' Uses (M)BG/CNBD-k model parameters and a customer's past transaction behavior 
#' to return the number of transactions they are expected to make in a given 
#' time period.
#' 
#' @param params A vector with model parameters \code{k}, \code{r}, 
#'   \code{alpha}, \code{a} and \code{b}, in that order.
#' @param T.star Length of time for which we are calculating the expected number
#'   of transactions.
#' @param x Number of repeat transactions in the calibration period T.cal, or a 
#'   vector of calibration period frequencies.
#' @param t.x Recency, i.e. length between first and last transaction during 
#'   calibration period.
#' @param T.cal Length of calibration period, or a vector of calibration period 
#'   lengths.
#' @return Number of transactions a customer is expected to make in a time 
#'   period of length t, conditional on their past behavior. If any of the input
#'   parameters has a length greater than 1, this will be a vector of expected 
#'   number of transactions.
#' @export
#' @references Platzer Michael, and Thomas Reutterer (forthcoming)
#' @examples
#' cbs <- cdnow.sample()$cbs # load CDNow summary data
#' params <- mbgcnbd.EstimateParameters(cbs)
#' xstar.est <- mbgcnbd.ConditionalExpectedTransactions(params, 
#'   cbs$T.star, cbs$x, cbs$t.x, cbs$T.cal)
#' head(xstar.est) # expected number of transactions for first 6 customers
#' sum(xstar.est) # expected total number of transactions during holdout
mbgcnbd.ConditionalExpectedTransactions <- function(params, T.star, x, t.x, T.cal) {
  xbgcnbd.ConditionalExpectedTransactions(params, T.star, x, t.x, T.cal, dropout_at_zero = TRUE)
}

#' @rdname mbgcnbd.ConditionalExpectedTransactions
#' @export
bgcnbd.ConditionalExpectedTransactions <- function(params, T.star, x, t.x, T.cal) {
  xbgcnbd.ConditionalExpectedTransactions(params, T.star, x, t.x, T.cal, dropout_at_zero = FALSE)
}

#' @keywords internal
xbgcnbd.ConditionalExpectedTransactions <- function(params, T.star, x, t.x, T.cal, dropout_at_zero = NULL) {
  stopifnot(!is.null(dropout_at_zero))
  max.length <- max(length(T.star), length(x), length(t.x), length(T.cal))
  if (max.length%%length(T.star)) 
    warning("Maximum vector length not a multiple of the length of T.star")
  if (max.length%%length(x)) 
    warning("Maximum vector length not a multiple of the length of x")
  if (max.length%%length(t.x)) 
    warning("Maximum vector length not a multiple of the length of t.x")
  if (max.length%%length(T.cal)) 
    warning("Maximum vector length not a multiple of the length of T.cal")
  dc.check.model.params.safe(c("k", "r", "alpha", "a", "b"), params, "xbgcnbd.ConditionalExpectedTransactions")
  if (params[1] != floor(params[1]) | params[1] < 1) 
    stop("k must be integer being greater or equal to 1.")
  if (any(T.star < 0) || !is.numeric(T.star)) 
    stop("T.star must be numeric and may not contain negative numbers.")
  if (any(x < 0) || !is.numeric(x)) 
    stop("x must be numeric and may not contain negative numbers.")
  if (any(t.x < 0) || !is.numeric(t.x)) 
    stop("t.x must be numeric and may not contain negative numbers.")
  if (any(T.cal < 0) || !is.numeric(T.cal)) 
    stop("T.cal must be numeric and may not contain negative numbers.")
  x <- rep(x, length.out = max.length)
  t.x <- rep(t.x, length.out = max.length)
  T.cal <- rep(T.cal, length.out = max.length)
  T.star <- rep(T.star, length.out = max.length)
  k <- params[1]
  r <- params[2]
  alpha <- params[3]
  a <- params[4]
  b <- params[5]
  if (round(a, 2) == 1) 
    a <- a + 0.01  # P1 not defined for a=1, so we add slight noise in such rare cases
  if (requireNamespace("gsl", quietly = TRUE)) {
    h2f1 <- gsl::hyperg_2F1
  } else {
    h2f1 <- function(a, b, c, z) {
      lenz <- length(z)
      j <- 0
      uj <- 1:lenz
      uj <- uj/uj
      y <- uj
      lteps <- 0
      while (lteps < lenz) {
        lasty <- y
        j <- j + 1
        uj <- uj * (a + j - 1) * (b + j - 1)/(c + j - 1) * z/j
        y <- y + uj
        lteps <- sum(y == lasty)
      }
      return(y)
    }
  }
  # approximate via expression for conditional expected transactions for BG/NBD model, but adjust scale parameter
  # by k
  G <- function(r, alpha, a, b) 1 - (alpha/(alpha + T.star))^r * h2f1(r, b + 1, a + b, T.star/(alpha + T.star))
  P1 <- (a + b + x - 1 + ifelse(dropout_at_zero, 1, 0))/(a - 1)
  P2 <- G(r + x, k * alpha + T.cal, a, b + x - 1 + ifelse(dropout_at_zero, 1, 0))
  P3 <- xbgcnbd.PAlive(params = params, x = x, t.x = t.x, T.cal = T.cal, dropout_at_zero = dropout_at_zero)
  exp <- P1 * P2 * P3
  # adjust bias BG/NBD-based approximation by scaling via the Unconditional Expectations (for wich we have exact
  # expression)
  if (k > 1) {
    sum.cal <- sum(xbgcnbd.Expectation(params = params, t = T.cal, dropout_at_zero = dropout_at_zero))
    sum.tot <- sum(xbgcnbd.Expectation(params = params, t = T.cal + T.star, dropout_at_zero = dropout_at_zero))
    bias.corr <- (sum.tot - sum.cal)/sum(exp)
    exp <- exp * bias.corr
  }
  return(exp)
}



#' (M)BG/CNBD-k Plot Frequency in Calibration Period
#' 
#' Plots a histogram and returns a matrix comparing the actual and expected
#' number of customers who made a certain number of repeat transactions in the
#' calibration period, binned according to calibration period frequencies.
#' 
#' @param params A vector with model parameters \code{k}, \code{r}, 
#'   \code{alpha}, \code{a} and \code{b}, in that order.
#' @param cal.cbs calibration period CBS (customer by sufficient statistic). It 
#'   must contain columns for frequency ('x') and total time observed ('T.cal').
#' @param censor Cutoff point for number of transactions in plot.
#' @param xlab Descriptive label for the x axis.
#' @param ylab Descriptive label for the y axis.
#' @param title Title placed on the top-center of the plot.
#' @return Calibration period repeat transaction frequency comparison matrix
#'   (actual vs. expected).
#' @export
#' @references Platzer Michael, and Thomas Reutterer (forthcoming)
#' @examples 
#' cbs <- cdnow.sample()$cbs
#' params <- mbgcnbd.EstimateParameters(cbs)
#' mbgcnbd.PlotFrequencyInCalibration(params, cbs)
mbgcnbd.PlotFrequencyInCalibration <- function(params, cal.cbs, censor = 7, 
                                               xlab = "Calibration period transactions", 
                                               ylab = "Customers", 
                                               title = "Frequency of Repeat Transactions") {
  xbgcnbd.PlotFrequencyInCalibration(params, cal.cbs, censor, xlab, ylab, title, dropout_at_zero = TRUE)
}

#' @rdname mbgcnbd.PlotFrequencyInCalibration
#' @export
bgcnbd.PlotFrequencyInCalibration <- function(params, cal.cbs, censor = 7, 
                                               xlab = "Calibration period transactions", 
                                               ylab = "Customers", 
                                               title = "Frequency of Repeat Transactions") {
  xbgcnbd.PlotFrequencyInCalibration(params, cal.cbs, censor, xlab, ylab, title, dropout_at_zero = FALSE)
}

#' @keywords internal
xbgcnbd.PlotFrequencyInCalibration <- function(params, cal.cbs, censor = 7, 
                                               xlab = "Calibration period transactions", 
                                               ylab = "Customers", 
                                               title = "Frequency of Repeat Transactions", 
                                               dropout_at_zero = NULL) {
  stopifnot(!is.null(dropout_at_zero))
  tryCatch(x_act <- cal.cbs$x, error = function(e) stop("Error in xbgcnbd.PlotFrequencyInCalibration: cal.cbs must have a frequency column labelled \"x\""))
  tryCatch(T.cal <- cal.cbs$T.cal, error = function(e) stop("Error in xbgcnbd.PlotFrequencyInCalibration: cal.cbs must have a column for length of time observed labelled \"T.cal\""))
  dc.check.model.params.safe(c("k", "r", "alpha", "a", "b"), params, "xbgcnbd.PlotFrequencyInCalibration")
  
  # actual
  x_act[x_act > censor] <- censor
  x_act <- table(x_act)
  
  # expected
  x_est <- sapply(unique(T.cal), function(tcal) {
    n <- sum(cal.cbs$T.cal == tcal)
    prop <- xbgcnbd.pmf(params, t = tcal, x=0:(censor-1), dropout_at_zero = dropout_at_zero)
    prop <- c(prop, 1-sum(prop))
    prop * (n / nrow(cal.cbs))
  })
  x_est <- apply(x_est, 1, sum) * nrow(cal.cbs)
  
  mat <- matrix(c(x_act, x_est), nrow = 2, ncol = censor + 1, byrow = TRUE)
  rownames(mat) <- c("n.x.actual", "n.x.expected")
  colnames(mat) <- c(0:(censor-1), paste0(censor, "+"))
  
  barplot(mat, beside = TRUE, col = 1:2, main = title, xlab = xlab, ylab = ylab, ylim = c(0, max(mat) * 1.1))
  legend("topright", legend = c("Actual", "Model"), col = 1:2, lty = 1, lwd = 2)
  
  colnames(mat) <- paste0("freq.", colnames(mat))
  mat
}



#' (M)BG/CNBD-k Expected Cumulative Transactions
#' 
#' Calculates the expected cumulative total repeat transactions by all customers
#' for the calibration and holdout periods.
#' 
#' @param params A vector with model parameters \code{k}, \code{r}, 
#'   \code{alpha}, \code{a} and \code{b}, in that order.
#' @param T.cal A vector to represent customers' calibration period lengths.
#' @param T.tot End of holdout period. Must be a single value, not a vector.
#' @param n.periods.final Number of time periods in the calibration and holdout
#'   periods.
#' @return Vector of length \code{n.periods.final} with expected cumulative
#'   total repeat transactions by all customers.
#' @export
#' @examples 
#' cbs <- cdnow.sample()$cbs
#' params <- mbgcnbd.EstimateParameters(cbs)
#' # Returns a vector containing cumulative repeat transactions for 546 days.
#' # All parameters are in weeks; the calibration period lasted 39 weeks
#' # and the holdout period another 39.
#' mbgcnbd.ExpectedCumulativeTransactions(params, T.cal = cbs$T.cal, T.tot = 78, n.periods.final = 78)
mbgcnbd.ExpectedCumulativeTransactions <- function(params, T.cal, T.tot, n.periods.final) {
  xbgcnbd.ExpectedCumulativeTransactions(params, T.cal, T.tot, n.periods.final, dropout_at_zero = TRUE)
}

#' @rdname mbgcnbd.ExpectedCumulativeTransactions
#' @export
bgcnbd.ExpectedCumulativeTransactions <- function(params, T.cal, T.tot, n.periods.final) {
  xbgcnbd.ExpectedCumulativeTransactions(params, T.cal, T.tot, n.periods.final, dropout_at_zero = FALSE)
}

#' @keywords internal
xbgcnbd.ExpectedCumulativeTransactions <- function(params, T.cal, T.tot, n.periods.final, dropout_at_zero = NULL) {
  stopifnot(!is.null(dropout_at_zero))
  dc.check.model.params.safe(c("k", "r", "alpha", "a", "b"), params, "xbgcnbd.ExpectedCumulativeTransactions")
  if (any(T.cal < 0) || !is.numeric(T.cal)) 
    stop("T.cal must be numeric and may not contain negative numbers.")
  if (length(T.tot) > 1 || T.tot < 0 || !is.numeric(T.tot)) 
    stop("T.cal must be a single numeric value and may not be negative.")
  if (length(n.periods.final) > 1 || n.periods.final < 0 || !is.numeric(n.periods.final)) 
    stop("n.periods.final must be a single numeric value and may not be negative.")
  
  intervals <- seq(T.tot/n.periods.final, T.tot, length.out = n.periods.final)
  cust.birth.periods <- max(T.cal) - T.cal
  expected.transactions <- sapply(intervals, function(interval) {
    if (interval <= min(cust.birth.periods)) 
      return(0)
    sum(xbgcnbd.Expectation(params = params, t = interval - cust.birth.periods[cust.birth.periods < interval], 
                            dropout_at_zero = dropout_at_zero))
  })
  return(expected.transactions)
}



#' (M)BG/CNBD-k Tracking Cumulative Transactions Plot
#' 
#' Plots the actual and expected cumulative total repeat transactions by all
#' customers for the calibration and holdout periods, and returns this
#' comparison in a matrix.
#' 
#' @param params A vector with model parameters \code{k}, \code{r}, 
#'   \code{alpha}, \code{a} and \code{b}, in that order.
#' @param T.cal A vector to represent customers' calibration period lengths.
#' @param T.tot End of holdout period. Must be a single value, not a vector.
#' @param actual.cu.tracking.data A vector containing the cumulative number of
#'   repeat transactions made by customers for each period in the total time
#'   period (both calibration and holdout periods).
#' @param xlab Descriptive label for the x axis.
#' @param ylab Descriptive label for the y axis.
#' @param xticklab A vector containing a label for each tick mark on the x axis.
#' @param title Title placed on the top-center of the plot.
#' @param ymax Upper boundary for y axis.
#' @return Matrix containing actual and expected cumulative repeat transactions.
#' @export
#' @seealso \code{\link{bgcnbd.PlotTrackingInc}}
#' @examples
#' cdnow <- cdnow.sample()
#' cbs <- cdnow$cbs
#' cum <- elog2cum(cdnow$elog)
#' params <- mbgcnbd.EstimateParameters(cbs)
#' mbgcnbd.PlotTrackingCum(params, cbs$T.cal, T.tot = 78, cum)
mbgcnbd.PlotTrackingCum <- function(params, T.cal, T.tot, actual.cu.tracking.data, 
                                    xlab = "Week", ylab = "Cumulative Transactions", 
                                    xticklab = NULL, title = "Tracking Cumulative Transactions", 
                                    ymax = NULL) {
  xbgcnbd.PlotTrackingCum(params, T.cal, T.tot, actual.cu.tracking.data, 
                          xlab, ylab, xticklab, title, ymax, dropout_at_zero = TRUE)
}

#' @rdname mbgcnbd.PlotTrackingCum
#' @export
bgcnbd.PlotTrackingCum <- function(params, T.cal, T.tot, actual.cu.tracking.data, 
                                    xlab = "Week", ylab = "Cumulative Transactions", 
                                    xticklab = NULL, title = "Tracking Cumulative Transactions", 
                                    ymax = NULL) {
  xbgcnbd.PlotTrackingCum(params, T.cal, T.tot, actual.cu.tracking.data, 
                          xlab, ylab, xticklab, title, ymax, dropout_at_zero = FALSE)
}

#' @keywords internal
xbgcnbd.PlotTrackingCum <- function(params, T.cal, T.tot, actual.cu.tracking.data, 
                                    xlab = "Week", ylab = "Cumulative Transactions", 
                                    xticklab = NULL, title = "Tracking Cumulative Transactions", 
                                    ymax = NULL, dropout_at_zero = NULL) {
  
  stopifnot(!is.null(dropout_at_zero))
  actual <- actual.cu.tracking.data
  expected <- xbgcnbd.ExpectedCumulativeTransactions(params, T.cal, T.tot, length(actual), 
                                                     dropout_at_zero = dropout_at_zero)
  
  dc.PlotTracking(actual = actual, expected = expected, T.cal = T.cal,
                  xlab = xlab, ylab = ylab, title = title, xticklab = xticklab, ymax = ymax)
}



#' (M)BG/CNBD-k Tracking Incremental Transactions Comparison
#' 
#' Plots the actual and expected incremental total repeat transactions by all
#' customers for the calibration and holdout periods, and returns this
#' comparison in a matrix.
#' 
#' @param params A vector with model parameters \code{k}, \code{r}, 
#'   \code{alpha}, \code{a} and \code{b}, in that order.
#' @param T.cal A vector to represent customers' calibration period lengths.
#' @param T.tot End of holdout period. Must be a single value, not a vector.
#' @param actual.inc.tracking.data A vector containing the incremental number of
#'   repeat transactions made by customers for each period in the total time
#'   period (both calibration and holdout periods).
#' @param xlab Descriptive label for the x axis.
#' @param ylab Descriptive label for the y axis.
#' @param xticklab A vector containing a label for each tick mark on the x axis.
#' @param title Title placed on the top-center of the plot.
#' @param ymax Upper boundary for y axis.
#' @return Matrix containing actual and expected incremental repeat transactions.
#' @export
#' @seealso \code{\link{bgcnbd.PlotTrackingCum}}
#' @examples
#' cdnow <- cdnow.sample()
#' cbs <- cdnow$cbs
#' inc <- elog2inc(cdnow$elog)
#' params <- mbgcnbd.EstimateParameters(cbs)
#' mbgcnbd.PlotTrackingInc(params, cbs$T.cal, T.tot = 78, inc)
mbgcnbd.PlotTrackingInc <- function(params, T.cal, T.tot, actual.inc.tracking.data, 
                                    xlab = "Week", ylab = "Transactions", 
                                    xticklab = NULL, title = "Tracking Weekly Transactions", 
                                    ymax = NULL) {
  xbgcnbd.PlotTrackingInc(params, T.cal, T.tot, actual.inc.tracking.data, 
                          xlab, ylab, xticklab, title, ymax, dropout_at_zero = TRUE)
}

#' @rdname mbgcnbd.PlotTrackingInc
#' @export
bgcnbd.PlotTrackingInc <- function(params, T.cal, T.tot, actual.inc.tracking.data, 
                                    xlab = "Week", ylab = "Transactions", 
                                    xticklab = NULL, title = "Tracking Weekly Transactions", 
                                    ymax = NULL) {
  xbgcnbd.PlotTrackingInc(params, T.cal, T.tot, actual.inc.tracking.data, 
                          xlab, ylab, xticklab, title, ymax, dropout_at_zero = FALSE)
}

#' @keywords internal
xbgcnbd.PlotTrackingInc <- function(params, T.cal, T.tot, actual.inc.tracking.data, 
                                    xlab = "Week", ylab = "Transactions", 
                                    xticklab = NULL, title = "Tracking Weekly Transactions", 
                                    ymax = NULL, dropout_at_zero = NULL) {
  
  stopifnot(!is.null(dropout_at_zero))
  actual <- actual.inc.tracking.data
  expected_cum <- xbgcnbd.ExpectedCumulativeTransactions(params, T.cal, T.tot, length(actual), 
                                                         dropout_at_zero = dropout_at_zero)
  expected <- BTYD::dc.CumulativeToIncremental(expected_cum)
  
  dc.PlotTracking(actual = actual, expected = expected, T.cal = T.cal, 
                  xlab = xlab, ylab = ylab, title = title, xticklab = xticklab, ymax = ymax)
}



#' Simulate data according to (M)BG/CNBD-k model assumptions
#' 
#' @param n Number of customers.
#' @param T.cal Length of calibration period. If a vector is provided, then it
#'   is assumed that customers have different 'birth' dates, i.e.
#'   \eqn{max(T.cal)-T.cal}.
#' @param T.star Length of holdout period. This may be a vector.
#' @param params A vector with model parameters \code{k}, \code{r}, 
#'   \code{alpha}, \code{a} and \code{b}, in that order.
#' @param return.elog If \code{TRUE} then the event log is returned in addition
#'   to the CBS summary.
#' @return List of length 2:
##' \itemize{
##'  \item{\code{cbs }}{A data.frame with a row for each customer and the summary statistic as columns.}
##'  \item{\code{elog }}{A data.frame with a row for each transaction, and columns \code{cust} and \code{t}.}
##' }
#' @export
#' @references Platzer Michael, and Thomas Reutterer (forthcoming)
#' @examples
#' params <- c(k = 3, r = 0.85, alpha = 1.45, a = 0.79, b = 2.42)
#' data <- mbgcnbd.GenerateData(n = 4000, T.cal = 24, T.star = 32, params, return.elog = TRUE)
#' 
#' # customer by sufficient summary statistic - one row per customer
#' head(data$cbs)
#' 
#' # event log - one row per event/transaction
#' head(data$elog)
mbgcnbd.GenerateData <- function(n, T.cal, T.star = NULL, params, return.elog = FALSE) {
  xbgcnbd.GenerateData(n, T.cal, T.star, params, return.elog, dropout_at_zero = TRUE)
}

#' @rdname mbgcnbd.GenerateData
#' @export
bgcnbd.GenerateData <- function(n, T.cal, T.star = NULL, params, return.elog = FALSE) {
  xbgcnbd.GenerateData(n, T.cal, T.star, params, return.elog, dropout_at_zero = FALSE)
}

#' @keywords internal
xbgcnbd.GenerateData <- function(n, T.cal, T.star = NULL, params, return.elog = FALSE, dropout_at_zero = NULL) {
  stopifnot(!is.null(dropout_at_zero))
  dc.check.model.params.safe(c("k", "r", "alpha", "a", "b"), params, "xbgcnbd.GenerateData")
  if (params[1] != floor(params[1]) | params[1] < 1) 
    stop("k must be integer being greater or equal to 1.")
  
  k <- params[1]
  r <- params[2]
  alpha <- params[3]
  a <- params[4]
  b <- params[5]
  
  if (length(T.cal) == 1) 
    T.cal <- rep(T.cal, n)
  
  # sample intertransaction timings parameter lambda for each customer
  lambdas <- rgamma(n, shape = r, rate = alpha)
  
  # sample churn-probability p for each customer
  ps <- rbeta(n, a, b)
  
  # sample intertransaction timings & churn
  cbs_list <- list()
  elog_list <- list()
  for (i in 1:n) {
    p <- ps[i]
    lambda <- lambdas[i]
    # sample no. of transactions until churn
    coins <- rbinom(min(10000, 10/p), 1, p)
    churn <- ifelse(any(coins == 1), min(which(coins == 1)), 10000)
    if (dropout_at_zero) 
      churn <- churn - 1
    # sample transaction times
    times <- cumsum(c(max(T.cal) - T.cal[i], rgamma(churn, shape = k, rate = lambda)))
    if (return.elog) 
      elog_list[[i]] <- data.table(cust = i, t = times[times <= (max(T.cal) + max(T.star))])
    # determine frequency, recency, etc.
    ts.cal <- times[times <= max(T.cal)]
    cbs_list[[i]] <- list(cust = i, x = length(ts.cal) - 1, t.x = max(ts.cal) - (max(T.cal) - T.cal[i]), litt = sum(log(diff(ts.cal))), 
                          churn = churn, alive = churn > (length(ts.cal) - 1))
    for (tstar in T.star) {
      colname <- paste0("x.star", ifelse(length(T.star) > 1, tstar, ""))
      cbs_list[[i]][[colname]] <- length(times[times > max(T.cal) & times <= (max(T.cal) + tstar)])
    }
  }
  cbs <- setDF(rbindlist(cbs_list))
  cbs$lambda <- lambdas
  cbs$p <- ps
  cbs$k <- k
  cbs$T.cal <- T.cal
  if (length(T.star) == 1) 
    cbs$T.star <- T.star
  rownames(cbs) <- NULL
  out <- list(cbs = cbs)
  if (return.elog) {
    out$elog <- setDF(rbindlist(elog_list))
  }
  return(out)
}