## python script to create stats of hdf5-file image content


import sys

import SimpleITK as sitk # for processing
import numpy as np # for processing

import h5py


argv = sys.argv


f = h5py.File(argv[1], 'r')

print("c\tMin\tMax\tMean\tStd\tVariance\tSum\tName\tSize")

for name in f: # http://docs.h5py.org/en/latest/quick.html#groups-and-hierarchical-organization
    D = f[name]
    d = sitk.GetImageFromArray(np.moveaxis(np.squeeze(D), 0, -1)) # https://docs.scipy.org/doc/numpy/reference/generated/numpy.squeeze.html
    stat = sitk.StatisticsImageFilter() # no procedural interface like sitk.Normalize(d) https://itk.org/SimpleITKDoxygen/html/classitk_1_1simple_1_1NormalizeImageFilter.html#details  https://itk.org/SimpleITKDoxygen/html/namespaceitk_1_1simple.html#a603f415c1d5f0475aff976d8d784dba7

    for i in range(d.GetNumberOfComponentsPerPixel()): # VectorIndexSelectionCast does not work for scalar images!
        if(d.GetNumberOfComponentsPerPixel() > 1):
            stat.Execute(sitk.VectorIndexSelectionCast(d, i)) # http://insightsoftwareconsortium.github.io/SimpleITK-Notebooks/Python_html/20_Expand_With_Interpolators.html # see resampler: https://itk.org/SimpleITKDoxygen/html/Python_2ImageRegistrationMethod2_8py-example.html
        else:
            stat.Execute(d)
        print("%d\t%f\t%f\t%f\t%f\t%f\t%f\t%s\t" # http://stackoverflow.com/questions/3264828/change-default-float-print-format
              % (
                  i,
                  stat.GetMinimum(),
                  stat.GetMaximum(),
                  stat.GetMean(),
                  stat.GetSigma(),
                  stat.GetVariance(),
                  stat.GetSum(),
                  name
              ), 
              D.shape
          )

f.close()
