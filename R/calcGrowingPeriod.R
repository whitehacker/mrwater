#' @title calcGrowingPeriod
#' @description This function determines a mean sowing date and a mean growing period for each cell
#' in order to determine when irrigation can take place.
#'
#' @param lpjml Defines LPJmL version for crop/grass and natveg specific inputs
#' @param climatetype Switch between different climate scenarios
#' @param stage Degree of processing: raw, smoothed, harmonized, harmonized2020
#' @param yield_ratio threshold for cell yield over global average. crops in cells below threshold will be ignored
#'
#' @return magpie object in cellular resolution
#' @author Kristine Karstens, Felicitas Beier
#'
#' @examples
#' \dontrun{
#' calcOutput("GrowingPeriod", aggregate = FALSE)
#' }
#'
#' @importFrom madrat toolGetMapping toolAggregate
#' @importFrom magclass collapseNames getItems new.magpie getYears dimSums magpie_expand
#' @importFrom mrcommons toolHarmonize2Baseline toolSmooth toolLPJmLVersion
#'
#' @export

calcGrowingPeriod <- function(lpjml = c(natveg = "LPJmL4_for_MAgPIE_44ac93de", crop = "ggcmi_phase3_nchecks_9ca735cb"),
                              climatetype = "GSWP3-W5E5:historical", stage = "harmonized2020", yield_ratio = 0.1) { #nolint

  cfgNatveg <- toolLPJmLVersion(version = lpjml["natveg"], climatetype = climatetype)
  cfgCrop   <- toolLPJmLVersion(version = lpjml["crop"],   climatetype = climatetype)

  lpjmlReadin  <- c(natveg = unname(cfgNatveg$readin_version),
                    crop   = unname(cfgCrop$readin_version))

  lpjmlBaseline <- c(natveg = unname(cfgNatveg$baseline_version),
                      crop  = unname(cfgCrop$baseline_version))

  if (stage %in% c("raw", "smoothed")) {

    ####################################################################################
    # Goal: calculate mean sowing date and growing period
    # Step 1 Take care of inconsistencies (harvest date or sowing date ==0 etc)
    #        and convert to magpie crop functional types
    # Step 2 Remove wintercrops from both calculations for the northern hemisphere: sowd>180, hard<sowd
    # Step 3 Remove crops that have an irrigated yield below 10% of global average
    #        (total cell area as aggregation weight for global value)
    # Step 4 Calculate growing period with the remaining crops
    # Step 5 Remove sowd1 for sowing date calculation
    # Step 6 Calculate mean sowing date
    # Step 7 Set the sowd to 1 and growing period to 365 where dams are present and
    #        where they are NA (reflecting that all crops have been eliminated)
    # Step 8 Calculate the growing days per month for each cell and each year

    ####################################################################################

    ####################################################################################
    # Read sowing and harvest date input (new for LPJmL5)
    ####################################################################################

    lpj2mag      <- toolGetMapping("MAgPIE_LPJmL.csv",
                                    type = "sectoral",
                                    where = "mappingfolder")

    # Read yields first
    yields <- toolCoord2Isocell(collapseNames(calcOutput("LPJmL_new", version = lpjmlReadin["crop"],
                                                          climatetype = climatetype, subtype = "harvest",
                                                          stage = "raw", aggregate = FALSE)[, , "irrigated"]))

    # Load Sowing dates from LPJmL (use just rainfed dates since they do not differ for irrigated and rainfed)
    sowd   <- toolCoord2Isocell(collapseNames(calcOutput("LPJmL_new", version = lpjmlReadin["crop"],
                                                          climatetype = climatetype,  subtype = "sdate",
                                                          stage = "raw", aggregate = FALSE)[, , "rainfed"]))
    hard   <- toolCoord2Isocell(collapseNames(calcOutput("LPJmL_new", version = lpjmlReadin["crop"],
                                                          climatetype = climatetype,  subtype = "hdate",
                                                          stage = "raw", aggregate = FALSE)[, , "rainfed"]))

    goodCrops <- lpj2mag$MAgPIE[which(lpj2mag$LPJmL %in% getItems(sowd, dim = 3))]
    badCrops  <- lpj2mag$MAgPIE[which(!lpj2mag$LPJmL %in% getItems(sowd, dim = 3))]

    sowd   <- toolAggregate(sowd, rel = lpj2mag,
                            from = "LPJmL", to = "MAgPIE",
                            dim = 3.1, partrel = TRUE)
    hard   <- toolAggregate(hard, rel = lpj2mag,
                            from = "LPJmL", to = "MAgPIE",
                            dim = 3.1, partrel = TRUE)
    yields <- toolAggregate(yields, rel = lpj2mag,
                            from = "LPJmL", to = "MAgPIE",
                            dim = 3.1, partrel = TRUE)

    if (length(badCrops) > 0) vcat(2, "No information on the growing period found for those crops: ",
                                    paste(unique(badCrops), collapse = ", "))

    #####################################################################################

    ####################################################################################
    # Step 1 Take care of inconsistencies (hard==0 etc)
    ####################################################################################

    # Set sowd to 1 and hard to 365 where either sowd or hard are 0
    sowd[which(hard == 0 | sowd == 0)] <- 1
    hard[which(hard == 0 | sowd == 0)] <- 365

    # Set hard to sowd-1 where sowd and hard are equal
    hard[which(hard == sowd & sowd > 1)]  <- sowd[which(hard == sowd & sowd > 1)] - 1 ### WHY???
    hard[which(hard == sowd & sowd == 1)] <- 365

    ####################################################################################

    ####################################################################################
    # Step 2 remove crops that have an irrigated yield below 10% of global average
    #        (total cell area as aggregation weight)
    ####################################################################################

    area   <- dimSums(calcOutput("LUH2v2", cellular = TRUE,
                                 aggregate = FALSE, years = "y1995"),
                      dim = 3)
    yields <- collapseNames(yields[, , goodCrops])

    cell2GLO     <- array(c(getItems(yields, dim = 1),
                          rep("GLO", 59199)), dim = c(59199, 2))
    gloYields   <- toolAggregate(yields, cell2GLO, weight = setYears(area, NULL))
    ratioYields <- yields / gloYields

    rmLowyield   <- yields
    rmLowyield[] <- 1
    rmLowyield[ratioYields < 0.1] <- NA

    rm(ratioYields, yields, area, gloYields)

    ####################################################################################

    ####################################################################################
    # Step 3 remove wintercrops from both calculations for the northern hemisphere: sowd>180, hard>365
    ####################################################################################

    cellsNorthernHemisphere <- which(magpie_coord[, 2] > 0)
    rmWintercrops            <- new.magpie(cells_and_regions = getCells(sowd),
                                            years = getYears(sowd),
                                            names = getNames(sowd),
                                            sets = c("region", "year", "crop"),
                                            fill = 1)

    # define all crops sowed after 180 days and where sowing date is after harvest date as wintercrops
    rmWintercrops[cellsNorthernHemisphere, , ] <-
      ifelse(sowd[cellsNorthernHemisphere, , ] > 180 &
               hard[cellsNorthernHemisphere, , ] < sowd[cellsNorthernHemisphere, , ],
             NA, 1)

    ####################################################################################

    ####################################################################################
    # Step 4 Calculate mean growing period with the remaining crops
    ####################################################################################

    # calculate growing period as difference of sowing date to harvest date
    # sowd <- sowd[,years,] #nolint
    # hard <- hard[,years,] #nolint
    growPeriod <- hard - sowd
    growPeriod[which(hard < sowd)] <- 365 + growPeriod[which(hard < sowd)]

    # calculate the mean after removing the before determined winter- and low yielding crops
    # rmWintercrops <- rmWintercrops[,years,] #nolint
    # rmLowyield    <- rmLowyield[,years,]    #nolint

    nCrops          <- dimSums(rmWintercrops * rmLowyield, dim = 3, na.rm = TRUE)
    meanGrper <- dimSums(growPeriod * rmWintercrops * rmLowyield, dim = 3, na.rm = TRUE) / nCrops
    meanGrper[is.infinite(meanGrper)] <- NA

    #############################################################################

    ####################################################################################
    # Step 5 remove sowd1 for sowing date calculation
    ####################################################################################

    rmSowd1          <- sowd
    rmSowd1[]        <- 1
    rmSowd1[sowd == 1] <- NA

    ####################################################################################

    ####################################################################################
    # Step 6 Calculate mean sowing date
    ####################################################################################

    nCrops   <- dimSums(rmWintercrops * rmLowyield * rmSowd1, dim = 3, na.rm = TRUE)
    meanSowd <- dimSums(growPeriod * rmWintercrops * rmLowyield * rmSowd1, dim = 3, na.rm = TRUE) / nCrops
    meanSowd[is.infinite(meanSowd)] <- NA

    rm(rmWintercrops, rmLowyield, rmSowd1)
    rm(sowd, hard, growPeriod)
    ####################################################################################

    ####################################################################################
    # Step 7 Set the sowd to 1 and growing period to 365 where dams are present and where they are NA
    #        (reflecting that all crops have been eliminated).
    ####################################################################################

    dams <- readSource("Dams", convert = "onlycorrect")

    for (t in getYears(meanSowd)) {
      meanSowd[which(dams == 1), t]        <- 1
      meanGrper[which(dams == 1), t] <- 365
    }

    meanSowd[is.na(meanSowd)]               <- 1
    meanGrper[is.na(meanGrper)] <- 365
    meanSowd         <- round(meanSowd)
    meanGrper  <- round(meanGrper)

    ####################################################################################

    ####################################################################################
    # Step 8 Calculate the growing days per month for each cell and each year
    ####################################################################################

    month        <- c("jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec")
    monthLength  <- c(31,   28,   31,   30,   31,   30,   31,   31,   30,   31,   30,   31)
    names(monthLength) <- month

    # Determine which day belongs to which month
    daysMonths        <- 1:365
    names(daysMonths) <- 1:365

    before <- 0
    for (i in seq_along(monthLength)) {
      daysMonths[(before + 1):(before + monthLength[i])]        <- i
      names(daysMonths)[(before + 1):(before + monthLength[i])] <- names(monthLength)[i]
      before <- before + monthLength[i]
    }

    # mag object for the growing days per month
    growDaysPerMonth <- new.magpie(cells_and_regions = getCells(meanSowd),
                                      years = getYears(meanSowd),
                                      names = month,
                                      fill = 0)

    # determine the harvest day, take care if it is greater than 365
    meanHard <- (meanSowd + meanGrper - 1) %% 365
    meanHard[meanHard == 0] <- 365

    meanHard <- as.array(meanHard)
    meanSowd <- as.array(meanSowd)
    growDaysPerMonth <- as.array(growDaysPerMonth)

    # Loop over the months to set the number of days that the growing period lasts in each month
    for (t in getYears(meanSowd)) {

      # goodcells are cells in which harvest date is after sowing date,
      # i.e. the cropping period does not cross the beginning of the year
      goodcells  <- ifelse(meanHard[, t, ] >= meanSowd[, t, ], 1, 0)
      badcells   <- ifelse(meanHard[, t, ] >= meanSowd[, t, ], 0, 1)

      #nolint start
      for (month in 1:12) {
        lastMonthday  <- which(daysMonths == month)[length(which(daysMonths == month))]
        firstMonthday <- which(daysMonths == month)[1]
        testHarvestGoodcells <- as.array(meanHard[, t, ] - firstMonthday + 1)
        daysInThisMonthGoodcells <- as.array(lastMonthday - meanSowd[, t, ] + 1)
        daysInThisMonthGoodcells[daysInThisMonthGoodcells < 0] <- 0 # Month before sowing date
        daysInThisMonthGoodcells[daysInThisMonthGoodcells > monthLength[month]] <- monthLength[month] # Month is completely after sowing date
        daysInThisMonthGoodcells[testHarvestGoodcells < 0] <- 0 # Month lies after harvest date
        daysInThisMonthGoodcells[testHarvestGoodcells > 0 & testHarvestGoodcells < monthLength[month]] <- daysInThisMonthGoodcells[testHarvestGoodcells > 0 & testHarvestGoodcells < monthLength[month]] - (lastMonthday - meanHard[testHarvestGoodcells > 0 & testHarvestGoodcells < monthLength[month], t, ]) # Harvest date lies in the month. cut off the end of the month after harvest date
        daysInThisMonthGoodcells <- daysInThisMonthGoodcells <- daysInThisMonthGoodcells * goodcells
        daysInThisMonthBadcellsFirstyear <- as.array(lastMonthday - meanSowd[, t, ] + 1)
        daysInThisMonthBadcellsFirstyear[daysInThisMonthBadcellsFirstyear < 0] <- 0 # Month before sowing date
        daysInThisMonthBadcellsFirstyear[daysInThisMonthBadcellsFirstyear > monthLength[month]] <- monthLength[month] # Month is completely after sowing date
        daysInThisMonthBadcellsSecondyear <- as.array(meanHard[, t, ] - firstMonthday + 1)
        daysInThisMonthBadcellsSecondyear[daysInThisMonthBadcellsSecondyear < 0] <- 0 # Month lies completely after harvest day
        daysInThisMonthBadcellsSecondyear[daysInThisMonthBadcellsSecondyear > monthLength[month]] <- monthLength[month] # Month lies completely before harvest day
        daysInThisMonthBadcells <- (daysInThisMonthBadcellsFirstyear + daysInThisMonthBadcellsSecondyear) * badcells

        growDaysPerMonth[, t, month] <- daysInThisMonthGoodcells + daysInThisMonthBadcells
      }
    } #nolint end

    out <- as.magpie(growDaysPerMonth)

    if (any(is.na(out))) {
      stop("calcGrowingPeriod produced NAs")
    }

    if (stage == "smoothed") {
      # Time smoothing
      out <- toolSmooth(out)
      # replace values above days of a month with days of the month & negative values with 0
      month        <- c("jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec")
      monthLength <- c(31,   28,   31,   30,   31,   30,   31,   31,   30,   31,   30,   31)
      names(monthLength) <- month
      out[out > as.magpie(monthLength)] <- magpie_expand(as.magpie(monthLength), out)[out > as.magpie(monthLength)]
      out[out < 0] <- 0

    }

  } else if (stage == "harmonized") {

    # load smoothed data
    baseline <- calcOutput("GrowingPeriod", lpjml = lpjmlBaseline, climatetype = cfgNatveg$baseline_hist,
                           stage = "smoothed", yield_ratio = yield_ratio, aggregate = FALSE)

    if (climatetype == cfgNatveg$baseline_hist) {

      out <- baseline

    } else {

      x        <- calcOutput("GrowingPeriod", lpjml = lpjmlReadin, climatetype = climatetype,
                             stage = "smoothed", yield_ratio = yield_ratio, aggregate = FALSE)
      # Harmonize to baseline
      out <- toolHarmonize2Baseline(x = x, base = baseline, ref_year = cfgNatveg$ref_year_hist)
    }

  } else if (stage == "harmonized2020") {

    # read in historical data for subtype
    baseline2020    <- calcOutput("GrowingPeriod", lpjml = lpjmlBaseline, climatetype = cfgNatveg$baseline_gcm,
                                  stage = "harmonized", yield_ratio = yield_ratio, aggregate = FALSE)

    if (climatetype == cfgNatveg$baseline_gcm) {
      out <- baseline2020

    } else {

      x        <- calcOutput("GrowingPeriod", lpjml = lpjmlReadin, climatetype = climatetype,
                             stage = "smoothed", yield_ratio = yield_ratio, aggregate = FALSE)
      out <- toolHarmonize2Baseline(x, baseline2020, ref_year = cfgNatveg$ref_year_gcm)
    }

  } else {
    stop("Stage argument not supported!")
 }

  # replace values above days of a month with days of the month & negative values with 0
  month        <- c("jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec")
  monthLength <- c(31,   28,   31,   30,   31,   30,   31,   31,   30,   31,   30,   31)
  names(monthLength) <- month
  out[out > as.magpie(monthLength)] <- magpie_expand(as.magpie(monthLength), out)[out > as.magpie(monthLength)]
  out[out < 0] <- 0

  return(list(x            = out,
              weight       = NULL,
              unit         = "days",
              description  = "Growing days per month",
              isocountries = FALSE))

}
