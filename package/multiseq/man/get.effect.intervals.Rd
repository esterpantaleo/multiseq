% Generated by roxygen2 (4.0.2): do not edit by hand
\name{get.effect.intervals}
\alias{get.effect.intervals}
\title{Print intervals where \code{\link{multiseq}} found strong effect (zero is outside of +/- \code{fra} * posterior standard deviation).}
\usage{
get.effect.intervals(res, fra, region = NULL)
}
\arguments{
\item{res:}{\code{\link{multiseq}} output.}

\item{fra:}{a multiplier of the standard deviation; this function will output intervals where multiseq found strong effect (zero is outside of +/- \code{fra} * posterior standard deviation).}

\item{region:}{a string specifying a genomic region: reference sequence name, start position, end position; defaults to NULL if provided, the function will output the interval in genomic coordinates.}
}
\value{
a list with elements \code{chr}, \code{start}, \code{end}, \code{sign} (of the effect), \code{fra}, \code{type} (type can be "local" or "sequence" and specifies whether start and end are relative to a genomic sequence).
}
\description{
Output interval is in \code{bed} format (\code{start} is 0-based, \code{end} is 1-based).
}
\examples{
\dontrun{
#run multiseq on sample data
samplesheet <- file.path(path.package("multiseq"), "extdata", "sim", "samplesheet.sim.txt")
region      <- "chr1:154206209-154214400"
x           <- get.counts(samplesheet, region)
samples     <- read.table(samplesheet, stringsAsFactors=F, header=T)
g           <- factor(samples$Tissue)
g           <- match(g, levels(g))-1
fra         <- 2
res <- multiseq(x=x, g=g, minobs=1, lm.approx=FALSE, read.depth=samples$ReadDepth)

get.effect.intervals(res, fra, region))
}
}

