#!/usr/bin/Rscript

library(SimpleITK)
library(Matrix)

regionfill3D <- function(im, regmask)
{
  imA <- as.array(im)
  regmask <- as.array(regmask)
  storage.mode(regmask)<-"logical"
  imdims <- dim(imA)
  vv <- prod(imdims)
  ll <- Matrix(0, nrow=vv, ncol=vv, sparse=TRUE)
  
  allmaskpix <- which(regmask)
  nonmaskpix <- which(!regmask)

  maskpixcoords <- arrayInd(allmaskpix, .dim=dim(regmask))

  edgepix <- (maskpixcoords[,1] == 1) +
      (maskpixcoords[,2] == 1) +
      (maskpixcoords[,3] == 1) +
      (maskpixcoords[,1] == imdims[1]) +
      (maskpixcoords[,2] == imdims[2]) +
      (maskpixcoords[,3] == imdims[3]) 

  maskpix <- allmaskpix[edgepix==0]

  maskpixedge <- allmaskpix[edgepix > 0]
  maskpixedgecoords <- maskpixcoords[edgepix > 0, ]

  rm(maskpixcoords)
  rm(allmaskpix)
  ll[cbind(maskpix, maskpix)] <- 1
  ll[cbind(nonmaskpix,nonmaskpix)] <- 1
  ## set up the ones that aren't edges
  ll[cbind(maskpix, maskpix+1)] <- -1/6
  ll[cbind(maskpix, maskpix-1)] <- -1/6
  ll[cbind(maskpix, maskpix+nrow(imA))] <- -1/6
  ll[cbind(maskpix, maskpix-nrow(imA))] <- -1/6
  ll[cbind(maskpix, maskpix+(nrow(imA)*ncol(imA)))] <- -1/6
  ll[cbind(maskpix, maskpix-(nrow(imA)*ncol(imA)))] <- -1/6

  ## deal with the edge effects
  ## can be dealing with up to 3 missing neighbours (for a corner).
  ## is there a nice vectorized way to do this
  ll[cbind(maskpixedge, maskpixedge)] <- 1
  newweights <- 1/(edgepix[edgepix>0] - 6)
  offsets <- c(1, imdims[1], imdims[1]*imdims[2])
  for (DIM in 1:3) {
      offset <- offsets[DIM]

      OK <- maskpixedgecoords[,DIM] != 1
      tpix <- maskpixedge[OK]
      ll[cbind(tpix, tpix - offset)] <- newweights[OK]

      OK <- maskpixedgecoords[,DIM] != imdims[DIM]
      tpix <- maskpixedge[OK]
      ll[cbind(tpix, tpix + offset)] <- newweights[OK]
  }
  rm(maskpixedge, maskpixcoords, edgepix, maskpixedgecoords, tpix, maskpix, newweights)
    
  b <- as.vector(imA)
  g<-solve(ll, b)
  g <- as.vector(g)
  dim(g) <- dim(imA)
  g <- as.image(g)
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
    if(length(args) != 3)
    	{
  	stop("Missing Parameters: <binary-input> <speed-output>")
	}
    s <- speedimage(args[1])
    WriteImages(s, args[2])
}

main()
