/*
 
 LAUCaptureVideoPreviewLayerGaussianFilterKernel.h
 LAUCaptureVideoPreviewLayer
 
 Copyright (c) 2016 Luis Laugga.
 Some rights reserved, all wrongs deserved.
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of
 this software and associated documentation files (the "Software"), to deal in
 the Software without restriction, including without limitation the rights to
 use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
 the Software, and to permit persons to whom the Software is furnished to do so,
 subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
 FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
 COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
 IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 
*/

#ifndef LAUCaptureVideoPreviewLayerGaussianFilterKernel_h
#define LAUCaptureVideoPreviewLayerGaussianFilterKernel_h

#warning "Objective-C — needs to be refactored and re-written in Swift"

#import <assert.h>
#import <math.h>

/*
 This values are generated from the matlab script:
 docs/matlab/LAUCaptureVideoPreviewLayer.m
 See project documentation for more details
 */

// Number of generated filter kernels
static unsigned int const kGaussianFilterKernelCount = 11;

unsigned int gaussianFilterKernelCount()
{
    return kGaussianFilterKernelCount;
}

#pragma mark -
#pragma mark Separable filtering with discrete texture sampling weights

// For each step [0,1] there's a different kernel.
// These kernels are used to animate between filter intensity values
static float const kDtsGaussianFilterKernel[11][45] = {
    { /* t */ 0.000000, /* sigma */ 0.250000, /* size */ 3, /* weights */ 0.000335,0.999330,0.000335 },
    { /* t */ 0.100000, /* sigma */ 1.697019, /* size */ 9, /* weights */ 0.014720,0.049627,0.118230,0.199036,0.236774,0.199036,0.118230,0.049627,0.014720 },
    { /* t */ 0.200000, /* sigma */ 3.108407, /* size */ 15, /* weights */ 0.010325,0.020232,0.035748,0.056954,0.081816,0.105976,0.123774,0.130348,0.123774,0.105976,0.081816,0.056954,0.035748,0.020232,0.010325 },
    { /* t */ 0.300000, /* sigma */ 4.449412, /* size */ 19, /* weights */ 0.011980,0.018404,0.026881,0.037328,0.049282,0.061860,0.073822,0.083759,0.090352,0.092663,0.090352,0.083759,0.073822,0.061860,0.049282,0.037328,0.026881,0.018404,0.011980 },
    { /* t */ 0.400000, /* sigma */ 5.687014, /* size */ 25, /* weights */ 0.007788,0.011113,0.015376,0.020626,0.026825,0.033827,0.041356,0.049022,0.056341,0.062780,0.067825,0.071045,0.072152,0.071045,0.067825,0.062780,0.056341,0.049022,0.041356,0.033827,0.026825,0.020626,0.015376,0.011113,0.007788 },
    { /* t */ 0.500000, /* sigma */ 6.790738, /* size */ 29, /* weights */ 0.007252,0.009718,0.012744,0.016353,0.020535,0.025232,0.030340,0.035698,0.041102,0.046308,0.051055,0.055081,0.058149,0.060072,0.060727,0.060072,0.058149,0.055081,0.051055,0.046308,0.041102,0.035698,0.030340,0.025232,0.020535,0.016353,0.012744,0.009718,0.007252 },
    { /* t */ 0.600000, /* sigma */ 7.733407, /* size */ 33, /* weights */ 0.006273,0.008129,0.010360,0.012983,0.016001,0.019394,0.023116,0.027096,0.031234,0.035407,0.039472,0.043274,0.046656,0.049468,0.051580,0.052890,0.053334,0.052890,0.051580,0.049468,0.046656,0.043274,0.039472,0.035407,0.031234,0.027096,0.023116,0.019394,0.016001,0.012983,0.010360,0.008129,0.006273 },
    { /* t */ 0.700000, /* sigma */ 8.491810, /* size */ 35, /* weights */ 0.006592,0.008287,0.010274,0.012562,0.015149,0.018016,0.021131,0.024443,0.027885,0.031373,0.034812,0.038095,0.041115,0.043762,0.045939,0.047559,0.048559,0.048897,0.048559,0.047559,0.045939,0.043762,0.041115,0.038095,0.034812,0.031373,0.027885,0.024443,0.021131,0.018016,0.015149,0.012562,0.010274,0.008287,0.006592 },
    { /* t */ 0.800000, /* sigma */ 9.047273, /* size */ 39, /* weights */ 0.005016,0.006289,0.007788,0.009527,0.011513,0.013744,0.016209,0.018883,0.021732,0.024706,0.027746,0.030783,0.033736,0.036525,0.039063,0.041271,0.043074,0.044410,0.045231,0.045508,0.045231,0.044410,0.043074,0.041271,0.039063,0.036525,0.033736,0.030783,0.027746,0.024706,0.021732,0.018883,0.016209,0.013744,0.011513,0.009527,0.007788,0.006289,0.005016 },
    { /* t */ 0.900000, /* sigma */ 9.386117, /* size */ 39, /* weights */ 0.005692,0.007023,0.008566,0.010330,0.012317,0.014521,0.016926,0.019506,0.022226,0.025039,0.027890,0.030715,0.033444,0.036005,0.038324,0.040333,0.041967,0.043175,0.043917,0.044167,0.043917,0.043175,0.041967,0.040333,0.038324,0.036005,0.033444,0.030715,0.027890,0.025039,0.022226,0.019506,0.016926,0.014521,0.012317,0.010330,0.008566,0.007023,0.005692 },
    { /* t */ 1.000000, /* sigma */ 9.500000, /* size */ 39, /* weights */ 0.005920,0.007267,0.008822,0.010592,0.012576,0.014768,0.017151,0.019699,0.022376,0.025137,0.027927,0.030686,0.033345,0.035835,0.038086,0.040034,0.041617,0.042786,0.043503,0.043744,0.043503,0.042786,0.041617,0.040034,0.038086,0.035835,0.033345,0.030686,0.027927,0.025137,0.022376,0.019699,0.017151,0.014768,0.012576,0.010592,0.008822,0.007267,0.005920 },
 
};

float dtsGaussianFilterStepForKernelIndex(int kernelIndex)
{
    assert(kernelIndex < kGaussianFilterKernelCount);
    
    return kDtsGaussianFilterKernel[kernelIndex][0];
}

float dtsGaussianFilterSigmaForKernelIndex(int kernelIndex)
{
    assert(kernelIndex < kGaussianFilterKernelCount);
    
    return kDtsGaussianFilterKernel[kernelIndex][1];
}

unsigned int dtsGaussianFilterSizeForKernelIndex(int kernelIndex)
{
    assert(kernelIndex < kGaussianFilterKernelCount);
    
    return (unsigned int)kDtsGaussianFilterKernel[kernelIndex][2];
}

unsigned int dtsGaussianFilterRadiusForKernelIndex(int kernelIndex)
{
    assert(kernelIndex < kGaussianFilterKernelCount);
    
    return (unsigned int)floor(dtsGaussianFilterSizeForKernelIndex(kernelIndex)/2.0f);
}

float dtsGaussianFilterWeightForIndexes(int kernelIndex, int weightIndex)
{
    assert(kernelIndex < kGaussianFilterKernelCount);

    unsigned int size = dtsGaussianFilterSizeForKernelIndex(kernelIndex);
    
    assert(weightIndex < size);
    
    return kDtsGaussianFilterKernel[kernelIndex][3+weightIndex]; // TODO make this safer :)
}

#pragma mark -
#pragma mark Bilinear texture sampling weights and offsets

// For each step [0,1] there's a different kernel.
// These kernels are used to animate between filter intensity values
static float const kBtsGaussianFilterKernel[11][25] = {
    { /* t */ 0.000000, /* sigma */ 0.250000, /* size */ 3, /* samples */ 10, /* offsets */ 0.000670,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000, /* weights */ 0.500000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000 },
    { /* t */ 0.100000, /* sigma */ 1.175000, /* size */ 7, /* samples */ 10, /* offsets */ 0.582001,2.140545,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000, /* weights */ 0.407006,0.092994,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000 },
    { /* t */ 0.200000, /* sigma */ 2.100000, /* size */ 11, /* samples */ 10, /* offsets */ 0.641014,2.361954,4.264948,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000, /* weights */ 0.266782,0.190745,0.042473,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000 },
    { /* t */ 0.300000, /* sigma */ 3.025000, /* size */ 15, /* samples */ 10, /* offsets */ 0.654416,2.432120,4.379477,6.329525,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000, /* weights */ 0.193274,0.189051,0.089808,0.027867,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000 },
    { /* t */ 0.400000, /* sigma */ 3.950000, /* size */ 17, /* samples */ 10, /* offsets */ 0.000000,1.475984,3.444153,5.412774,7.382089,0.000000,0.000000,0.000000,0.000000,0.000000, /* weights */ 0.052112,0.192622,0.140526,0.079658,0.035082,0.000000,0.000000,0.000000,0.000000,0.000000 },
    { /* t */ 0.500000, /* sigma */ 4.875000, /* size */ 21, /* samples */ 10, /* offsets */ 0.000000,1.484226,3.463249,5.442400,7.421753,9.401376,0.000000,0.000000,0.000000,0.000000, /* weights */ 0.042224,0.160323,0.130192,0.089504,0.052091,0.025665,0.000000,0.000000,0.000000,0.000000 },
    { /* t */ 0.600000, /* sigma */ 5.800000, /* size */ 25, /* samples */ 10, /* offsets */ 0.000000,1.488854,3.474013,5.459217,7.444493,9.429865,11.415359,0.000000,0.000000,0.000000, /* weights */ 0.035490,0.136814,0.118049,0.090517,0.061680,0.037350,0.020099,0.000000,0.000000,0.000000 },
    { /* t */ 0.700000, /* sigma */ 6.725000, /* size */ 29, /* samples */ 10, /* offsets */ 0.000000,1.491709,3.480662,5.469634,7.458636,9.447678,11.436770,13.425923,0.000000,0.000000, /* weights */ 0.030607,0.119109,0.106707,0.087548,0.065781,0.045264,0.028523,0.016461,0.000000,0.000000 },
    { /* t */ 0.800000, /* sigma */ 7.650000, /* size */ 33, /* samples */ 10, /* offsets */ 0.000000,1.493593,3.485053,5.476522,7.468005,9.459506,11.451031,13.442584,15.434171,0.000000, /* weights */ 0.026906,0.105358,0.096766,0.083027,0.066551,0.049835,0.034863,0.022784,0.013910,0.000000 },
    { /* t */ 0.900000, /* sigma */ 8.575000, /* size */ 37, /* samples */ 10, /* offsets */ 0.000000,1.494900,3.488102,5.481309,7.474523,9.467745,11.460980,13.454229,15.447495,17.440780, /* weights */ 0.024003,0.094399,0.088214,0.078084,0.065469,0.051996,0.039117,0.027874,0.018815,0.012030 },
    { /* t */ 1.000000, /* sigma */ 9.500000, /* size */ 39, /* samples */ 10, /* offsets */ 0.665434,2.493075,4.487537,6.482002,8.476472,10.470947,12.465429,14.459920,16.454421,18.448932, /* weights */ 0.065375,0.084402,0.078120,0.069179,0.058613,0.047513,0.036851,0.027345,0.019414,0.013187 },
};

float btsGaussianFilterStepForKernelIndex(int kernelIndex)
{
    assert(kernelIndex < kGaussianFilterKernelCount);
    
    return kBtsGaussianFilterKernel[kernelIndex][0];
}

float btsGaussianFilterSigmaForKernelIndex(int kernelIndex)
{
    assert(kernelIndex < kGaussianFilterKernelCount);
    
    return kBtsGaussianFilterKernel[kernelIndex][1];
}

unsigned int btsGaussianFilterSizeForKernelIndex(int kernelIndex)
{
    assert(kernelIndex < kGaussianFilterKernelCount);
    
    return (unsigned int)kBtsGaussianFilterKernel[kernelIndex][2];
}

unsigned int btsGaussianFilterRadiusForKernelIndex(int kernelIndex)
{
    assert(kernelIndex < kGaussianFilterKernelCount);
    
    return (unsigned int)floor(btsGaussianFilterSizeForKernelIndex(kernelIndex)/2.0f);
}

unsigned int btsGaussianFilterSamplesForKernelIndex(int kernelIndex)
{
    assert(kernelIndex < kGaussianFilterKernelCount);
    
    return (unsigned int)kBtsGaussianFilterKernel[kernelIndex][3];
}

float btsGaussianFilterWeightForIndexes(int kernelIndex, int sampleIndex)
{
    assert(kernelIndex < kGaussianFilterKernelCount);
    
    unsigned int samples = btsGaussianFilterSamplesForKernelIndex(kernelIndex);
    
    assert(sampleIndex < samples);
    
    return kBtsGaussianFilterKernel[kernelIndex][4+samples+sampleIndex]; // TODO make this safer :)
}

float btsGaussianFilterOffsetForIndexes(int kernelIndex, int sampleIndex)
{
    assert(kernelIndex < kGaussianFilterKernelCount);
    
    unsigned int samples = btsGaussianFilterSamplesForKernelIndex(kernelIndex);
    
    assert(sampleIndex < samples);
    
    return kBtsGaussianFilterKernel[kernelIndex][4+sampleIndex]; // TODO make this safer :)
}

#endif /* LAUCaptureVideoPreviewLayerGaussianFilterKernel_h */
