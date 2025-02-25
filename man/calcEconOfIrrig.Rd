% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/calcEconOfIrrig.R
\name{calcEconOfIrrig}
\alias{calcEconOfIrrig}
\title{calcEconOfIrrig}
\usage{
calcEconOfIrrig(
  scenario,
  output,
  gtrange,
  selectyears,
  iniyear,
  lpjml,
  climatetype,
  efrMethod,
  accessibilityrule,
  rankmethod,
  yieldcalib,
  allocationrule,
  irrigationsystem,
  landScen,
  cropmix,
  transDist,
  fossilGW,
  comAg,
  multicropping
)
}
\arguments{
\item{scenario}{non-agricultural water use scenario}

\item{output}{output to be displayed: irrigated area "IrrigArea" or
available water volume "wat_ag_ww" "wat_ag_wc"}

\item{gtrange}{range of x-axis (gainthreshold) to be depicted on the curve}

\item{selectyears}{years for which irrigatable area is calculated}

\item{iniyear}{initialization year}

\item{lpjml}{LPJmL version required for respective inputs: natveg or crop}

\item{climatetype}{Switch between different climate scenarios or historical baseline "GSWP3-W5E5:historical"}

\item{efrMethod}{EFR method used including selected strictness of EFRs (e.g. Smakhtin:good, VMF:fair)}

\item{accessibilityrule}{Method used: Quantile method (Q) or Coefficient of Variation (CV)
combined with scalar value defining the strictness of accessibility restriction:
discharge that is exceeded x percent of the time on average throughout a year
(Qx, e.g. Q75: 0.25, Q50: 0.5)
or base value for exponential curve separated by : (CV:2)}

\item{rankmethod}{Rank and optimization method consisting of
Unit according to which rank is calculated:
USD_ha (USD per hectare) for relative area return, or
USD_m3 (USD per cubic meter) for relative volumetric return;
USD for absolute return (total profit);
Price aggregation:
"GLO" for global average prices, or
"ISO" for country-level prices
and boolean indicating fullpotential (TRUE, i.e. cell
receives full irrigation requirements in total area)
or reduced potential (FALSE, reduced potential of cell
receives at later stage in allocation algorithm);
separated by ":"}

\item{yieldcalib}{If TRUE: LPJmL yields calibrated to FAO country yield in iniyear
     Also needs specification of refYields, separated by ":".
     Options: FALSE (for single cropping analyses) or
              "TRUE:actual:irrig_crop" (for multiple cropping analyses)
If FALSE: uncalibrated LPJmL yields are used}

\item{allocationrule}{Rule to be applied for river basin discharge allocation
across cells of river basin ("optimization", "upstreamfirst", "equality")}

\item{irrigationsystem}{Irrigation system used
("surface", "sprinkler", "drip", "initialization")}

\item{landScen}{Land availability scenario consisting of two parts separated by ":":
1. available land scenario (currCropland, currIrrig, potCropland)
2. protection scenario (WDPA, BH, FF, CPD, LW, HalfEarth, BH_IFL, NA).
For case of no land protection select "NA"
or do not specify second part of the argument}

\item{cropmix}{Selected cropmix (options:
"hist_irrig" for historical cropmix on currently irrigated area,
"hist_total" for historical cropmix on total cropland,
or selection of proxycrops)}

\item{transDist}{Water transport distance allowed to fulfill locally
unfulfilled water demand by surrounding cell water availability}

\item{fossilGW}{If TRUE: non-renewable groundwater can be used.
If FALSE: non-renewable groundwater cannot be used.}

\item{comAg}{if TRUE: the currently already irrigated areas
         in initialization year are reserved for irrigation,
if FALSE: no irrigation areas reserved (irrigation potential)}

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
calculates potentially irrigated area for different gainthresholds
             subject to land and water constraints
}
\examples{
\dontrun{
calcEconOfIrrig(aggregate = FALSE)
}

}
\author{
Felicitas Beier
}
