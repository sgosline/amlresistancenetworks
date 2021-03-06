% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/molecularSigs.R
\name{miniReg}
\alias{miniReg}
\title{miniReg
Runs lasso regression on a single feature from tabular data}
\usage{
miniReg(tab, mol.feature)
}
\arguments{
\item{tab}{with column names `AML sample`,meanVal,Gene, and whatever the value of 'mol.feature' is.}
}
\value{
a data.frame with three values/columns: MSE, numFeatures, and Genes
}
\description{
miniReg
Runs lasso regression on a single feature from tabular data
}
