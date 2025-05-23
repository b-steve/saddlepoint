% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/D-RandomlyStoppedSumCGF.R
\name{randomlyStoppedSumCGF}
\alias{randomlyStoppedSumCGF}
\title{CGF Object for a Randomly-Stopped Sum}
\usage{
randomlyStoppedSumCGF(
  count_cgf,
  summand_cgf,
  block_size = NULL,
  iidReps = NULL,
  ...
)
}
\arguments{
\item{count_cgf}{A \code{CGF} object corresponding to the distribution of \eqn{N}
in the sum \eqn{\tilde{Y} = \sum_{i=1}^{N} \tilde{X}_i}.}

\item{summand_cgf}{A \code{CGF} object corresponding to the summand random variables
\eqn{\tilde{X}_i} in the sum.}

\item{block_size}{(Optional) A positive integer specifying the size of each
block i.i.d. replication; or \code{NULL} (the default) to skip block-size replication.}

\item{iidReps}{(Optional) A positive integer specifying how many i.i.d. blocks
to expect; or \code{NULL} (the default) to skip i.i.d. replication.}

\item{...}{Additional named arguments passed to CGF creation functions.}
}
\value{
A \code{CGF} object for the distribution of \eqn{\sum_{i=1}^N \tilde{X}_i}.
}
\description{
Constructs the CGF for a randomly stopped sum
\eqn{\tilde{Y} = \sum_{i=1}^{N} \tilde{X}_i}{Y = sum(X[1], X[2], ..., X[N])},
where \eqn{N} is a non-negative integer-valued random variable with CGF object
specified by \code{count_cgf}, and each \eqn{\tilde{X}_i} is an i.i.d. random
vector with CGF specified by \code{summand_cgf}.
\eqn{N} is independent of \eqn{\tilde{X}_i}.

Optionally, the resulting CGF object can be replicated in i.i.d. blocks if
\code{iidReps} or \code{block_size} (or both) are specified.
}
\details{
\strong{Setup}:
\deqn{{\tilde{Y} = \sum_{i=1}^{N} \tilde{X}_i}}
The random variable \eqn{\tilde{Y}} is computed as the sum of \eqn{N} i.i.d copies of the random vector \eqn{\tilde{X}_i}. Each \eqn{\tilde{X}_i} is a random vector of arbitrary dimension \eqn{d}.
For example, when \eqn{d=3}:
\deqn{ \tilde{X_1} = (X_{11}, X_{12}, X_{13}) }
\deqn{ \tilde{X_2} = (X_{21}, X_{22}, X_{23}) }
\deqn{ ... }
\deqn{ \tilde{X_N} = (X_{N1}, X_{N2}, X_{N3}) }
Here, \eqn{X_{i1}, X_{i2}, X_{i3}} are scalars but the vectors \eqn{\tilde{X_i}} are i.i.d copies.

\strong{Optional Replication}:
If \code{block_size} or \code{iidReps} (or both) are specified, the function
automatically calls \code{\link{iidReplicatesCGF}} on the resulting CGF.
You may specify:
\enumerate{
\item \code{iidReps} only,
\item \code{block_size} only,
\item \strong{both} \code{iidReps} and \code{block_size}.
}
If both are provided, the input dimension of the final CGF must be
\code{block_size * iidReps}.
}
\examples{
\dontrun{
# For example, let count_cgf be the CGF of N ~ Poisson(lambdaN),
# and summand_cgf be the CGF of X ~ Gamma(shape, rate).
# Then Y = sum_{i=1..N} X_i is a compound Poisson-Gamma distribution.

cgf_Y <- randomlyStoppedSumCGF(count_cgf = PoissonCGF, summand_cgf = GammaCGF)


}
}
