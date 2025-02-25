% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/calcYieldImprovementPotential.R
\name{calcYieldImprovementPotential}
\alias{calcYieldImprovementPotential}
\title{calcYieldImprovementPotential}
\usage{
calcYieldImprovementPotential(
  lpjml,
  climatetype,
  yieldgaintype,
  priceAgg,
  iniyear,
  selectyears,
  cropmix,
  yieldcalib,
  multicropping
)
}
\arguments{
\item{lpjml}{LPJmL version used for yields}

\item{climatetype}{Climate scenarios or historical baseline "GSWP3-W5E5:historical"}

\item{yieldgaintype}{Crop yield gain through
multiple cropping under rainfed conditions "multicropping_rf",
multiple cropping under irrigated conditions "multicropping_ir",
irrigation under single cropping conditions "irrigation_singlecropping"
irrigation and multiple cropping "irrigation_multicropping"}

\item{priceAgg}{Price aggregation:
"GLO" for global average prices, or
"ISO" for country-level prices, or
"CONST" for same price for all crops}

\item{iniyear}{initialization year for food price and cropmix area}

\item{selectyears}{Years to be returned by the function}

\item{cropmix}{Selected cropmix for which yield improvement potential
is calculated (options:
"hist_irrig" for historical cropmix on currently irrigated area,
"hist_total" for historical cropmix on total cropland,
or selection of proxycrops)
NULL returns all crops individually}

\item{yieldcalib}{If TRUE: LPJmL yields calibrated to FAO country yield in iniyear
         Also needs specification of refYields, separated by ":".
         Options: FALSE (for single cropping analyses) or
                  "TRUE:actual:irrig_crop" (for multiple cropping analyses)
If FALSE: uncalibrated LPJmL yields are used}

\item{multicropping}{Multicropping activated (TRUE) or not (FALSE) and
Multiple Cropping Suitability mask selected
(mask can be:
"none": no mask applied (only for development purposes)
"actual:total": currently multicropped areas calculated from total harvested areas
                and total physical areas per cell from readLanduseToolbox
"actual:crop" (crop-specific), "actual:irrigation" (irrigation-specific),
"actual:irrig_crop" (crop- and irrigation-specific) "total"
"potential:endogenous": potentially multicropped areas given
                        temperature and productivity limits
"potential:exogenous": potentially multicropped areas given
                       GAEZ suitability classification)
(e.g. TRUE:actual:total; TRUE:none; FALSE)}
}
\value{
magpie object in cellular resolution
}
\description{
This function calculates the yield improvement potential
             through irrigation or multiple cropping per grid cell
             for a given cropmix
}
\examples{
\dontrun{
calcOutput("YieldImprovementPotential", aggregate = FALSE)
}

}
\author{
Felicitas Beier
}
