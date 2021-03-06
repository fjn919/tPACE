% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/MakeFPCAInputs.R
\name{MakeFPCAInputs}
\alias{MakeFPCAInputs}
\title{Format FPCA input}
\usage{
MakeFPCAInputs(IDs = NULL, tVec, yVec, na.rm = FALSE, sort = FALSE)
}
\arguments{
\item{IDs}{n-by-1 vector of subject IDs (Default: NULL)}

\item{tVec}{Either an n-by-1 vector of measurement times, or a p-by-1 vector corresponding to the common time support}

\item{yVec}{n-by-1 vector of measurements from the variable of interest, or a n-by-p matrix with each row corresponding to the dense observations.}

\item{na.rm}{logical indicating if NA should be omitted (Default: FALSE)}

\item{sort}{logical indicating if the returned lists Lt and Ly should be ensured to be sorted (Default: FALSE)}
}
\value{
L list containing 3 lists each of length 'm', 'm' being the number of unique subject IDs
}
\description{
Turn vector inputs to the list so they can be used in FPCA
}
