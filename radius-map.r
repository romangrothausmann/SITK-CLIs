#!/usr/bin/Rscript

library(SimpleITK)
library(Matrix)

regionfill3D <- function(im, regmask)
{
  ## More efficient version that only holds the interpolation
  ## area and boundaries. Means that setting up the neighbourhood is much
  ## trickier.
  imA <- as.array(im)
  ## Create a mask of pixels around regmask - we only
  ## need those ones, not the entire image
  boundarymaskIm <- BinaryDilate(regmask) - regmask
  regmask <- as.array(regmask)
  storage.mode(regmask)<-"logical"

  boundarymask <- as.array(boundarymaskIm)
  storage.mode(boundarymask) <- "logical"
    
  imdims <- dim(imA)

  ## All these indexes refer to image position
  allmaskpix <- which(regmask)
  nonmaskpix <- which(boundarymask)

  allpix <- sort(unique(c(allmaskpix, nonmaskpix)))

  matsize <- length(allpix)
  
  maskpixcoords <- arrayInd(allmaskpix, .dim=dim(regmask))

  edgepix <- (maskpixcoords[,1] == 1) +
      (maskpixcoords[,2] == 1) +
      (maskpixcoords[,3] == 1) +
      (maskpixcoords[,1] == imdims[1]) +
      (maskpixcoords[,2] == imdims[2]) +
      (maskpixcoords[,3] == imdims[3]) 

  weights <- 1/(edgepix - 2*length(imdims))
    
  ll <- Matrix(0, nrow=matsize, ncol=matsize, sparse=TRUE)

  idx <- match(nonmaskpix, allpix)
  ll[cbind(idx,idx)] <- 1
  idx <- match(allmaskpix, allpix)
  ll[cbind(idx, idx)] <- 1

  offsets <- c(1, imdims[1], imdims[1]*imdims[2])

 
  for (DIM in 1:length(imdims)) {
      offset <- offsets[DIM]
          
      OK <- maskpixcoords[,DIM] != 1
      tpix <- allmaskpix[OK]
      
      ll[cbind(match(tpix,allpix),
               match(tpix - offset, allpix))] <- weights[OK]
      
      OK <- maskpixcoords[,DIM] != imdims[DIM]
      tpix <- allmaskpix[OK]
      ll[cbind(match(tpix, allpix),
               match(tpix + offset, allpix))] <- weights[OK]
  }
  b <- as.vector(imA[allpix])
  g<-solve(ll, b)
  imA[allpix] <- as.vector(g)
  g <- as.image(imA)
  g$CopyInformation(im)
  return(g)
}

speedimage <- function(disttransfile) {
    ## Normally we wouldn't be calling garbage collection
    ## all the time, but better safe than sorry
    dt <- ReadImage(disttransfile, "sitkFloat32")
    wth <- WhiteTopHat(dt)
    ## wth is a greyscale image. We want to preserve
    ## internal structure. Careful to use Euclidean distances
    ## in the DT so that the tophat output doesn't depend on
    ## structure size. (Differences between adjacent pixels will
    ## be bigger for bigger vessels if we work with squared distances
    ## Now we want to interpolate between the background mask and the nonzero
    ## wth to generate a speed function that can be reliably scaled to 0-1 range.

    ## attempt 1 - multiply wth by 1e5
    wth <- wth * 1e5

    ## Outside vessels will be set to 0
    interpmask <- (wth == 0) & (dt > 0)
    rm(dt)
    gc()
    interp <- regionfill3D(wth, interpmask)
    return(interp)
}

main <- function() {
    args <- commandArgs(TRUE)
    if(length(args) != 5)
    	{
  	stop("Missing Parameters: <binary-input> <mnimasked> <lrmask> <seed-output> <regionfill3DB-output>")
	}

    dt <- ReadImage(args[1], "sitkFloat32")

    system.time( s <- speedimage(args[1]))
    WriteImage(s, args[4])
    

    mni <- ReadImage(args[2])
    msk <- ReadImage(args[3], "sitkUInt8")

    WriteImage(regionfill3DB(mni, msk), args[5])
    
}

main()
