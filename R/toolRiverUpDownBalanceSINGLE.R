#' @title       toolRiverUpDownBalanceSINGLE
#' @description This function calculates the cell water balance
#'              under consideration of different reserved human uses
#'              (non-agricultural, neighbor water requirements,
#'               committed-agricultural uses)
#'
#' @param inLIST         List of objects that are inputs to the function:
#'                       previously reserved withdrawals and consumption in current cell;
#'                       currently requested withdrawal in current cell
#' @param inoutLIST      List of objects that are inputs to the function and
#'                       are updated by the function:
#'                       discharge (including up- and downstream cells)
#'                       currently requested consumption (including upstream cells)
#'
#' @importFrom madrat calcOutput
#' @importFrom magclass collapseNames getNames new.magpie getCells setCells mbind setYears dimSums
#' @importFrom stringr str_split
#'
#' @return list of arrays objects in cellular resolution
#' @author Felicitas Beier, Jens Heinke
#'
#' @export

toolRiverUpDownBalanceSINGLE <- function(inLIST, inoutLIST) {

  # Inputs (not altered in this iteration of the algorithm):
  prevWC <- inLIST$prevWC
  prevWW <- inLIST$prevWW
  currWW <- inLIST$currWW

  # Inputs that are also outputs (updated by this algorithm):
  q      <- inoutLIST$q
  currWC <- inoutLIST$currWC

  # Available water
  # (Note: since it is compared to water reserved in previous time step,
  #        it needs to include prevWC, otherwise: there would be double-accouting)
  avlWat <- q[1] + prevWC

  ############################################
  ### Upstream-Downstream Water Accounting ###
  ###         and flow reservation         ###
  ############################################

  #### Available Water in cell is sufficient to fulfill previously determined requirements ####
  ####  -> further withdrawals possible                                                    ####
  # Is there sufficient water available to fulfill previously determined requirements?
  if (avlWat >= prevWW) {
    # Are current withdrawals requested?
    if (currWW > 0) {
      # (I) Water withdrawal constraint: All withdrawals that can be fulfilled considering
      #                                  local previously determined water requirements are served
      frac <- min((avlWat - prevWW) / currWW,
                  1)

      # Current water uses fulfilled given withdrawal constraint
      currWC[1] <- frac * currWC[1]
    }
    # Update discharge in current cell and downstream cells
    # for case where sufficient water available for requirements
    # (Subtract local water consumption in current cell (and previous if applicable)
    q <- q - currWC[1]

  } else {
    ###########################
    ### Upstream adjustment ###
    ###########################
    #### Available Water in cell is not sufficient to fulfill previously determined requirements ####
    #### -> no more water can be withdrawn locally                                               ####
    #### &  if possible: upstream consumption is reduced to release missing water                ####
    # (Note: This is necessary to allocate the release of water
    #        equally to all upstream cells (considering all
    #        tributaries and all cells in each of them))

    # No local water consumption if available water is not sufficient to fulfill
    # previously determined requirements
    currWC[1] <- 0

    if (length(currWC) > 1) {
      # Upstream cells
      upCELLS <- seq(2, length(currWC), 1)
      # Determine upstream current water consumption:
      upstreamWC <- sum(currWC[upCELLS])

      # Fraction that needs to be released by upstream cells
      # (Note: avlWat is strictly < prevWW because of if-condition above
      #        therefore upstreamWC is strictly positive)
      frac <- ifelse(upstreamWC > (prevWW - avlWat),
                      (prevWW - avlWat) / upstreamWC,
                     1)
      # Update discharge of current cell and its downstream cells
      q <- q + frac * upstreamWC
      # Reduce current human uses in upstreamcells
      currWC[upCELLS] <- (1 - frac) * currWC[upCELLS]
    }
  }

  outLIST <- list(q = q,
                  currWC = currWC)

  return(outLIST)
}
