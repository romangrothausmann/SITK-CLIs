#!/usr/bin/env Rscript

library(SimpleITK)

simplespeedimage <- function(disttransfile, resultfile, bglevel=0.005, sigma=-1) {
    ## bglevel - proportion of maximum wth filter output
    ## A simple approach to creating a speed image. The raw distance
    ## transform isn't great, apparently, because of the range of sizes
    ## of vessel. The requirement for the speed image to be in the range 0 to 1
    ## means that the range of values in small vessels tends to be quite small,
    ## thus there isn't much difference between the middle and edge. The minimal
    ## path is therefore less constrained to remain near the middle.
    ##
    ## The idea behind this speed image is to detect the ridge lines in the
    ## distance transform, via a white top hat, add a small background
    ## value to the zero voxels and smooth everything. The small background
    ## value ensures that there is a valid path when the white top hat result
    ## has discontinuities.
    ##
    ## Potential tweaks: should the centre of a big vessel be weighted more
    ## heavily than the centre of a small vessel? There are various approaches
    ## to doing this, for example, multiplying the wth by the distance transform
    ## (or function of it), or by applying the wth to the squared transform.
    ## danger is that we end up with the compression problem again.
    ##
    ## We may not need the background constant value - blurring may be enough.
    ##
    ## I'm using gc() explicitly here. Normally this is a silly thing to do,
    ## but I'm right on the edge of RAM limits.
    ##
    dt <- ReadImage(disttransfile, "sitkFloat32")
    wth <- WhiteTopHat(dt)
    vessels <- dt > 0
    ## the wth image is a continuous approximation of the skeleton
    ## it will be non zero at ridges in the distance transform.
    rm(dt)
    gc()
    St <- StatisticsImageFilter()
    St$Execute(wth)
    MX <- St$GetMaximum()
    bgconst <- MX * bglevel
    bgvessels <- Cast(vessels, 'sitkFloat32') * bgconst

    wth <- wth+bgvessels
    gc()
    # Smooth
    if (sigma < 0) {
       ## use a default single voxel smoothing
       sp <- wth$GetSpacing()
       sigma <- min(sp)
    }
    wth <- SmoothingRecursiveGaussian(wth, sigma)
    # Mask by nonzero parts of DistTrans
    wth <- Mask(wth, vessels)

    ## Recompute the statistics
    St$Execute(wth)
   
    SMX <- St$GetMaximum()
    wth <- wth/SMX
    WriteImage(wth, resultfile)
    invisible(NULL)
}

main <- function() {
    args <- commandArgs(TRUE)
    if(length(args) != 2)
    	{
  	stop("Missing Parameters: <distancetransform-input> <speed-output>")
	}
    s <- simplespeedimage(args[1], args[2])
}

main()
