% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/trainAndTestMolSigs.R
\name{combRegEval}
\alias{combRegEval}
\title{combReg
Runs lasso regression on a combination of feature types}
\usage{
combRegEval(
  tab,
  feature.list = c("proteinLevels", "mRNALevels", "geneMutations")
)
}
\value{
a data frame with three values/columns
}
\description{
combReg
Runs lasso regression on a combination of feature types
}
