% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/C-NormalCGF.R
\docType{data}
\name{NormalCGF}
\alias{NormalCGF}
\title{Univariate Normal CGF object}
\format{
An object of class \code{CGF} (R6), with the usual methods \code{K, K1, K2, etc.}
}
\usage{
NormalCGF
}
\description{
A ready-to-use CGF object for the univariate Normal distribution with mean
\eqn{\mu} and standard deviation \eqn{\sigma}. By default, \code{NormalCGF} evaluation for i.i.d. replicates.
If \code{tvec} has length \eqn{n}, we interpret that as \eqn{n} i.i.d. replicates.
}
\details{
\strong{Parameter Vector}: The \code{parameter_vector} used when calling methods such as \code{K(tvec, parameter_vector)}
must be a numeric vector of the form \eqn{(\mu, \sigma)} in that order.
}
\examples{
NormalCGF$K1(0, c(5, 0.5)) # (expected value for N(5, 0.5) is 5)

}
\keyword{datasets}
