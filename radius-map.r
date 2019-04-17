## R code - original version used SimpleITK
## 3d version below is using oro.nifti to load the test data.

## Clone of the matlab region fill operation that uses big sparse matrices
# library(SimpleITK)
library(oro.nifti)
library(Matrix)
regionfill <- function(im, regmask)
{
  im <- Mask(im, !regmask)
  imA <- as.array(im)
  regmask <- as.array(regmask)
  storage.mode(regmask)<-"logical"
  vv <- nrow(imA)*ncol(imA)
  ll <- Matrix(0, nrow=vv, ncol=vv)

  maskpix <- which(regmask)
  nonmaskpix <- which(!regmask)
  ll[cbind(maskpix, maskpix)] <- 1
  ll[cbind(nonmaskpix,nonmaskpix)] <- 1
  ## Need to deal with edge effects
  ll[cbind(maskpix, maskpix+1)] <- -0.25
  ll[cbind(maskpix, maskpix-1)] <- -0.25
  ll[cbind(maskpix, maskpix+nrow(imA))] <- -0.25
  ll[cbind(maskpix, maskpix-nrow(imA))] <- -0.25
  b <- as.vector(imA)
  g<-solve(ll, b)
  dim(g) <- dim(imA)
  g <- as.image(as.matrix(g))
  g$CopyInformation(im)
  return(g)
}

regionfill3D <- function(im, regmask)
{
    result <- im
  #im <- Mask(im, !regmask)
  imA <- as.array(im)
  regmask <- as.array(regmask)
  storage.mode(regmask)<-"logical"
  vv <- prod(dim(imA))
  ll <- Matrix(0, nrow=vv, ncol=vv)

  maskpix <- which(regmask)
  nonmaskpix <- which(!regmask)
  ll[cbind(maskpix, maskpix)] <- 1
  ll[cbind(nonmaskpix,nonmaskpix)] <- 1
  ## Need to deal with edge effects - ignore for now
  ll[cbind(maskpix, maskpix+1)] <- -1/6
  ll[cbind(maskpix, maskpix-1)] <- -1/6
  ll[cbind(maskpix, maskpix+nrow(imA))] <- -1/6
  ll[cbind(maskpix, maskpix-nrow(imA))] <- -1/6
  ll[cbind(maskpix, maskpix+(nrow(imA)*ncol(imA)))] <- -1/6
  ll[cbind(maskpix, maskpix-(nrow(imA)*ncol(imA)))] <- -1/6

  b <- as.vector(imA)
  g<-solve(ll, b)
  g <- as.vector(g)
  dim(g) <- dim(imA)
  #g$CopyInformation(im)
  return(g)
}


function() {
ct<-ReadImage("cthead1.png", 'sitkUInt8')
#m <- ReadImage("ctmask.nii.gz", 'sitkUInt8')
#m <- m[,,1,drop=TRUE]
#WriteImage(m, "ctmask.png")
m<-ReadImage("ctmask.png", 'sitkUInt8')

p<-regionfill(ct,m)
WriteImage(Cast(p, 'sitkUInt8'), "filled.png")
ctcrop <- ct[,100:200]
mcrop <- m[,100:200]

pcrop <- regionfill(ctcrop,mcrop)
WriteImage(Cast(pcrop, 'sitkUInt8'), "filledcrop.png")

## Test creating a field
## One rectangle inside a circle

blank <- ct*0
blank$SetPixel(c(128,128), 1)
dt <- DanielssonDistanceMap(blank)

outside <- 100*(dt > 80)

inside <- ct*0
inside$SetPixel(c(128,128), 1)
inside <- BinaryDilate(inside, vectorRadius=c(50, 20), kernel='sitkBox')
walls <- inside+outside
WriteImage(walls, "walls.nii.gz")

g<- regionfill(walls, walls==0)
WriteImage(g, "field.nii.gz")
}

function() {
    mni <- oro.nifti::readNIfTI("mnimasked.nii.gz")
    msk <- oro.nifti::readNIfTI("mnimasked_mask.nii.gz")

    mf <- regionfill3D(img_data(mni), img_data(msk))

    mnifilled <- mni
    img_data(mnifilled) <- mf
    oro.nifti::writeNIfTI(mnifilled, "filled.nii.gz")
}
