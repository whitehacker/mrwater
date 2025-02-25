#' @title       calcIrrigAreaPotential
#' @description Calculates area that can potentially be irrigated per crop given
#'              available water and land
#'
#' @param cropAggregation   TRUE (aggregated Potentially Irrigated Areas (PIAs)),
#'                          FALSE (crop-specific PIAs)
#' @param lpjml             LPJmL version used
#' @param climatetype       Switch between different climate scenarios or
#'                          historical baseline "GSWP3-W5E5:historical"
#' @param selectyears       Years for which irrigatable area is calculated
#' @param iniyear           Initialization year for initial croparea
#' @param efrMethod         EFR method used including selected strictness of EFRs (e.g. Smakhtin:good, VMF:fair)
#' @param accessibilityrule Strictness of accessibility restriction:
#'                          discharge that is exceeded x percent of the time on average throughout a year (Qx).
#'                          (e.g. Q75: 0.25, Q50: 0.5)
#' @param rankmethod        Rank and optimization method consisting of
#'                          Unit according to which rank is calculated:
#'                          USD_ha (USD per hectare) for relative area return, or
#'                          USD_m3 (USD per cubic meter) for relative volumetric return;
#'                          USD for absolute return (total profit);
#'                          Price aggregation:
#'                          "GLO" for global average prices, or
#'                          "ISO" for country-level prices
#'                          and boolean indicating fullpotential (TRUE, i.e. cell
#'                          receives full irrigation requirements in total area)
#'                          or reduced potential (FALSE, reduced potential of cell
#'                          receives at later stage in allocation algorithm);
#'                          separated by ":"
#' @param yieldcalib        If TRUE: LPJmL yields calibrated to FAO country yield in iniyear
#'                               Also needs specification of refYields, separated by ":".
#'                               Options: FALSE (for single cropping analyses) or
#'                                        "TRUE:actual:irrig_crop" (for multiple cropping analyses)
#'                          If FALSE: uncalibrated LPJmL yields are used
#' @param allocationrule    Rule to be applied for river basin discharge allocation
#'                          across cells of river basin ("optimization", "upstreamfirst", "equality")
#' @param gainthreshold     Threshold of yield improvement potential required
#'                          (in USD per hectare)
#' @param irrigationsystem  Irrigation system used
#'                          ("surface", "sprinkler", "drip", "initialization")
#' @param landScen          Land availability scenario consisting of two parts separated by ":":
#'                          1. available land scenario (currCropland, currIrrig, potCropland)
#'                          2. protection scenario (WDPA, BH, FF, CPD, LW, HalfEarth, BH_IFL, NA).
#'                          For case of no land protection select "NA"
#'                          or do not specify second part of the argument
#' @param cropmix           Selected cropmix (options:
#'                          "hist_irrig" for historical cropmix on currently irrigated area,
#'                          "hist_total" for historical cropmix on total cropland,
#'                          or selection of proxycrops)
#' @param comAg             If TRUE: currently already irrigated areas in
#'                                   initialization year are reserved for irrigation,
#'                          if FALSE: no irrigation areas reserved (irrigation potential)
#' @param fossilGW          If TRUE: non-renewable groundwater can be used.
#'                          If FALSE: non-renewable groundwater cannot be used.
#' @param multicropping     Multicropping activated (TRUE) or not (FALSE) and
#'                          Multiple Cropping Suitability mask selected
#'                          (mask can be:
#'                          "none": no mask applied (only for development purposes)
#'                          "actual:total": currently multicropped areas calculated from total harvested areas
#'                                          and total physical areas per cell from readLanduseToolbox
#'                          "actual:crop" (crop-specific), "actual:irrigation" (irrigation-specific),
#'                          "actual:irrig_crop" (crop- and irrigation-specific) "total"
#'                          "potential:endogenous": potentially multicropped areas given
#'                                                  temperature and productivity limits
#'                          "potential:exogenous": potentially multicropped areas given
#'                                                 GAEZ suitability classification)
#'                          (e.g. TRUE:actual:total; TRUE:none; FALSE)
#' @param transDist         Water transport distance allowed to fulfill locally
#'                          unfulfilled water demand by surrounding cell water availability
#'
#' @return magpie object in cellular resolution
#' @author Felicitas Beier
#'
#' @examples
#' \dontrun{
#' calcOutput("IrrigAreaPotential", aggregate = FALSE)
#' }
#'
#' @importFrom stringr str_split
#' @importFrom madrat calcOutput
#' @importFrom magclass collapseNames add_dimension add_columns mbind

calcIrrigAreaPotential <- function(cropAggregation,
                                   lpjml, climatetype,
                                   selectyears, iniyear,
                                   efrMethod, accessibilityrule,
                                   rankmethod, yieldcalib, allocationrule,
                                   gainthreshold, irrigationsystem, landScen,
                                   cropmix, comAg, fossilGW,
                                   multicropping, transDist) {

  ## Read in water available for irrigation (in mio. m^3)
  avlWat <- calcOutput("WaterUsePotential", selectyears = selectyears,
                        lpjml = lpjml, climatetype = climatetype, efrMethod = efrMethod,
                        accessibilityrule = accessibilityrule, rankmethod = rankmethod,
                        yieldcalib = yieldcalib, allocationrule = allocationrule,
                        gainthreshold = gainthreshold,
                        irrigationsystem = irrigationsystem, iniyear = iniyear,
                        landScen = landScen, cropmix = cropmix,
                        comAg = comAg, multicropping = multicropping,
                        transDist = transDist, fossilGW = fossilGW,
                        aggregate = FALSE)
  avlWatWC <- collapseNames(avlWat[, , "wat_ag_wc"])
  avlWatWW <- collapseNames(avlWat[, , "wat_ag_ww"])

  if (comAg) {

    # multiple cropping as of current multiple cropping pattern
    m <- as.logical(stringr::str_split(multicropping, ":")[[1]][1])
    if (m) {
      m <- "TRUE:actual:irrig_crop"
    } else {
      m <- FALSE
    }

    # Actually committed irrigated area (crop-specific)
    comAgArea <- calcOutput("IrrigAreaActuallyCommitted",
                            fossilGW = fossilGW,
                            lpjml = lpjml, climatetype = climatetype,
                            selectyears = selectyears, iniyear = iniyear,
                            efrMethod = efrMethod, multicropping = m,
                            transDist = transDist, aggregate = FALSE)
    names(dimnames(comAgArea))[2] <- "year"
    getSets(comAgArea) <- c("x", "y", "iso", "year", "crop", "irrig_type", "EFP", "scen")
    comAgArea <- collapseNames(dimOrder(comAgArea, perm = c(3, 4, 2, 1), dim = 3))

    # Water actually committed to agriculture (in mio. m^3)
    comWater <- calcOutput("RiverHumanUseAccounting",
                           iteration = "committed_agriculture",
                           lpjml = lpjml, climatetype = climatetype,
                           transDist = transDist, comAg = NULL,
                           efrMethod = efrMethod, multicropping = m,
                           selectyears = selectyears, iniyear = iniyear,
                           accessibilityrule = NULL,
                           rankmethod = NULL, gainthreshold = NULL,
                           cropmix = NULL, yieldcalib = NULL,
                           irrigationsystem = NULL, landScen = NULL,
                           aggregate = FALSE)
    comWatWW <- collapseNames(comWater[, , "currHumanWWtotal"])
    comWatWC <- collapseNames(comWater[, , "currHumanWCtotal"])

    # Fossil groundwater use
    if (fossilGW) {
      gw <- calcOutput("NonrenGroundwatUse", output = "comAg",
                       lpjml = lpjml, climatetype = climatetype,
                       selectyears = selectyears, iniyear = iniyear,
                       aggregate = FALSE)
      comWatWW <- comWatWW + collapseNames(gw[, , "withdrawal"])
      comWatWC <- comWatWC + collapseNames(gw[, , "consumption"])
    }


  } else {

    # No water or areas committed to current agricultural uses
    comAgArea <- 0
    comWatWW <- comWatWC <- avlWatWC
    comWatWW[, , ] <- 0
    comWatWC[, , ] <- 0
  }

  # Water available for potential additional irrigation (in mio. m^3)
  avlWatWW <- avlWatWW - comWatWW
  avlWatWC <- avlWatWC - comWatWC

  # Irrigation water requirements for selected cropmix and irrigation system per cell (in mio. m^3)
  watReq   <- calcOutput("FullIrrigationRequirement", selectyears = selectyears,
                         lpjml = lpjml, climatetype = climatetype, iniyear = iniyear,
                         irrigationsystem = irrigationsystem, landScen = landScen,
                         cropmix = cropmix, multicropping = multicropping,
                         comagyear = NULL, efrMethod = NULL,
                         transDist = NULL,
                         aggregate = FALSE)
  watReqWW <- watReqWC <- new.magpie(cells_and_regions = getItems(avlWatWW, dim = 1),
                                     years = getItems(avlWatWW, dim = 2),
                                     names = getItems(avlWatWW, dim = 3),
                                     fill = NA)

  watReqWW[, , ] <- collapseNames(watReq[, , "withdrawal"])
  watReqWC[, , ] <- collapseNames(watReq[, , "consumption"])

  # Read in area that can potentially be irrigated
  # (including total potentially irrigatable area; defined by comagyear=NULL)
  areaPotIrrig <- calcOutput("AreaPotIrrig",
                             selectyears = selectyears, iniyear = iniyear,
                             landScen = landScen, comagyear = NULL,
                             lpjml = NULL, climatetype = NULL,
                             efrMethod = NULL,
                             multicropping = NULL, transDist = NULL,
                             aggregate = FALSE)

  # share of requirements that can be fulfilled given available water, when >1 whole area can be irrigated
  irrigareaWW <- pmin(avlWatWW / watReqWW, 1) * areaPotIrrig
  irrigareaWW[watReqWW == 0] <- 0      # cells with no water requirements also get no irrigated area assigned
  irrigareaWW <- add_dimension(irrigareaWW, dim = 3.4, add = "type",
                               nm = "irrigatable_ww")

  irrigareaWC <- pmin(avlWatWC / watReqWC, 1) * areaPotIrrig
  irrigareaWC[watReqWC == 0] <- 0
  irrigareaWC <- add_dimension(irrigareaWC, dim = 3.4, add = "type",
                               nm = "irrigatable_wc")

  irrigatableArea <- pmin(collapseNames(irrigareaWW), collapseNames(irrigareaWC))
  irrigatableArea <- add_dimension(irrigatableArea, dim = 3.4, add = "type",
                                   nm = "irrigatable")

  # share of crop area by crop type given chosen cropmix
  cropareaShr <- calcOutput("CropAreaShare",
                            iniyear = iniyear, cropmix = cropmix,
                            aggregate = FALSE)

  # crop-specific potentially irrigated area
  out <- collapseNames(irrigatableArea * cropareaShr)
  out <- out + comAgArea

  # check for NAs and negative values
  if (any(is.na(out))) {
    stop("produced NA irrigatable area")
  }
  if (any(out < 0)) {
    stop("produced negative irrigatable area")
  }

  if (cropAggregation) {
    out <- dimSums(out, dim = "crop")
    description <- paste0("Potentially irrigated area (total)",
                          "given land and water constraints")
  } else {
    description <- paste0("Crop-specific area that can be irrigated",
                          "given land and water constraints")
  }

  return(list(x            = out,
              weight       = NULL,
              unit         = "Mha",
              description  = description,
              isocountries = FALSE))
}
