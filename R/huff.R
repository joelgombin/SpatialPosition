#' @title Huff Catchment Areas
#' @name huff
#' @description This function computes the catchment areas as defined by D. Huff (1964).
#' @param knownpts sp object (SpatialPointsDataFrame or SpatialPolygonsDataFrame); 
#' this is the set of known observations to estimate the catchment areas from.
#' @param unknownpts sp object (SpatialPointsDataFrame or SpatialPolygonsDataFrame); 
#' this is the set of unknown units for which the function computes the estimates. 
#' Not used when \code{resolution} is set up. (optional)
#' @param matdist matrix; distance matrix between known observations and unknown 
#' units for which the function computes the estimates. Row names match the row 
#' names of \code{knownpts} and column names match the row names of 
#' \code{unknownpts}. \code{matdist} can contain any distance metric (time 
#' distance or euclidean distance for example). If \code{matdist} is NULL, Great 
#' Circle distances are used (with \code{\link{CreateDistMatrix}}). (optional)
#' @param varname character; name of the variable in the \code{knownpts} dataframe 
#' from which values are computed. Quantitative variable with no negative values. 
#' @param typefct character; spatial interaction function. Options are "pareto" 
#' (means power law) or "exponential".
#' If "pareto" the interaction is defined as: (1 + alpha * mDistance) ^ (-beta).
#' If "exponential" the interaction is defined as: 
#' exp(- alpha * mDistance ^ beta).
#' The alpha parameter is computed from parameters given by the user 
#' (\code{beta} and \code{span}).
#' @param span numeric; distance where the density of probability of the spatial 
#' interaction function equals 0.5.
#' @param beta numeric; impedance factor for the spatial interaction function.  
#' @param resolution numeric; resolution of the output SpatialPointsDataFrame
#'  (in map units). If resolution is not set, the grid will contain around 
#'  7250 points. (optional)
#' @param mask sp object; the spatial extent of this object is used to 
#' create the regularly spaced SpatialPointsDataFrame output. (optional)
#' @param bypassctrl passed on to the \code{bypassctrl} argument of the \code{\link{CreateDistMatrix}} function. 
#' @return SpatialPointsDataFrame with the computed catchment areas in a new 
#' field named \code{OUTPUT}.
#' @seealso \link{huff}, \link{rasterHuff}, \link{plotHuff}, \link{CreateGrid}, 
#' \link{CreateDistMatrix}.
#' @examples 
#' # Create a SpatialPointsDataFrame grid of spatMask extent and 200 meters 
#' # resolution
#' data(spatData)
#' mygrid <- CreateGrid(w = spatMask, resolution = 200)
#' # Create a distance matrix between known points (spatPts) and mygrid
#' mymat <- CreateDistMatrix(knownpts = spatPts, unknownpts = mygrid)
#' # Compute Huff catchment areas from known points (spatPts) on a given 
#' # grid (mygrid) using a given distance matrix (mymat)
#' myhuff <- huff(knownpts = spatPts, unknownpts = mygrid, 
#'                matdist = mymat, varname = "Capacite", 
#'                typefct = "exponential", span = 1250, 
#'                beta = 3, mask = spatMask)
#' # Compute Huff catchment areas from known points (spatPts) on a 
#' # grid defined by its resolution
#' myhuff2 <- huff(knownpts = spatPts, varname = "Capacite", 
#'                       typefct = "exponential", span = 1250, beta = 3, 
#'                       resolution = 200, mask = spatMask)
#' # The two methods have the same result
#' identical(myhuff, myhuff2)
#' # the function output a SpatialPointsDataFrame
#' class(myhuff)
#' @references HUFF D. (1964) Defining and Estimating a Trading Area. Journal of Marketing, 28: 34-38.
#' @import sp
#' @import raster
#' @export
huff <- function(knownpts,
                 unknownpts = NULL,
                 matdist = NULL,
                 varname,
                 typefct = "exponential", 
                 span,
                 beta,
                 resolution = NULL,
                 mask = NULL,
                 bypassctrl = FALSE)
{
  TestSp(knownpts)
  if (!is.null(unknownpts)){  
    TestSp(unknownpts)
    if(identicalCRS(knownpts,unknownpts) == FALSE){
      stop(paste("Inputs (",quote(knownpts), " and ",quote(unknownpts),
                 ") do not use the same projection", sep = ""),call. = FALSE)
    }
    if (!is.null(matdist)){
      matdist <- UseDistMatrix(matdist =matdist, knownpts = knownpts, 
                               unknownpts =  unknownpts) 
    }else{
      matdist <- CreateDistMatrix(knownpts = knownpts, unknownpts = unknownpts, bypassctrl = bypassctrl) 
    }
  } else {
    unknownpts <- CreateGrid(w = if(is.null(mask)){knownpts} else {mask}, 
                             resolution = resolution) 
    matdist <- CreateDistMatrix(knownpts = knownpts, unknownpts = unknownpts, bypassctrl = bypassctrl) 
  }
  
  
  matdens <- ComputeInteractDensity(matdist = matdist, typefct = typefct,
                                    beta = beta, span = span)
  
  matopport <- ComputeOpportunity(knownpts = knownpts, matdens = matdens, 
                                  varname = varname)
  
  unknownpts <- ComputeHuff(unknownpts = unknownpts, 
                            matopport = matopport)
  
  return(unknownpts)
}

#' @title Create a Raster from a Huff SpatialPointsDataFrame
#' @name rasterHuff
#' @description This function creates a raster from a regularly spaced 
#' Huff SpatialPointsDataFrame (output of the \code{\link{huff}} function). 
#' @param x sp object (SpatialPointsDataFrame); output of the \code{huff} function.
#' @param mask sp object (SpatialPolygonsDataFrame); this object is used to clip 
#' the raster. (optional)
#' @return Raster of catchment areas values.
#' @seealso \link{huff}, \link{rasterHuff}, \link{plotHuff}, \link{CreateGrid}, 
#' \link{CreateDistMatrix}.
#' @examples 
#' data(spatData)
#' # Compute Huff catchment areas from known points (spatPts) on a
#' # grid defined by its resolution
#' myhuff <- huff(knownpts = spatPts, varname = "Capacite",
#'                typefct = "exponential", span = 750, beta = 2,
#'                resolution = 100, mask = spatMask)
#' # Create a raster of huff values
#' myhuffraster <- rasterHuff(x = myhuff, mask = spatMask)
#' plot(myhuffraster)
#' @import sp
#' @import raster
#' @export
rasterHuff <- function(x, mask = NULL){
  gridded(x) <- TRUE
  r <- raster(x)
  rasterx <- rasterize(x, r, field = 'OUTPUT')
  if(!is.null(mask)){
    TestSp(mask)
    rasterx <- mask(rasterx, mask = mask)
  }
  return(rasterx)
}

#' @title Plot a Huff Raster
#' @name plotHuff
#' @description This function plots the raster produced by the 
#' \code{\link{rasterHuff}} function.
#' @param x raster; output of the \code{\link{rasterHuff}} function.
#' @param add logical; if TRUE the raster is added to the current plot, if FALSE 
#' the raster is displayed in a new plot.
#' @return Display the raster nicely.
#' @seealso \link{huff}, \link{rasterHuff}, \link{plotHuff}, \link{CreateGrid}, 
#' \link{CreateDistMatrix}.
#' @examples 
#' data(spatData)
#' # Compute Huff catchment areas from known points (spatPts) on a
#' # grid defined by its resolution
#' myhuff <- huff(knownpts = spatPts, varname = "Capacite",
#'                typefct = "exponential", span = 750, beta = 2,
#'                resolution = 100, mask = spatMask)
#' # Create a raster of huff values
#' myhuffraster <- rasterHuff(x = myhuff, mask = spatMask)
#' plotHuff(myhuffraster)
#' @import raster
#' @export
plotHuff <- function(x, add = FALSE){
  bks <- seq(from = cellStats(x, min), 
             to = cellStats(x, max), length.out = 11)
  col <- c("#543005", "#8C510A", "#BF812D", "#DFC27D", 
           "#F6E8C3","#C7EAE5", "#80CDC1", "#35978F", 
           "#01665E", "#003C30")
  plot(x, breaks = bks, legend = FALSE, axes = FALSE,
       box = FALSE, col = col,  add = add)
  plot(x, legend.only=TRUE, col = col, 
       breaks=round(bks, 0) )
}




