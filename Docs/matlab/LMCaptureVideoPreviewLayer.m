%% LAUCaptureVideoPreviewLayer 
%
% Research and gaussian blur filter kernel generation for LAUCaptureVideoPreviewLayer 
% Copyright 2016 Luis Laugga. Some rights reserved, all wrongs deserved.
%

%% Gloabal Parameters

kMinSigma = 0.25;  % Min std. deviation used
kMaxSigma = 9.5;   % Max std. deviation used
kKernelCount = 11; % Number of different kernels generated, interval [kMinSigma, kMaxSigma]
kDownsamplingFactor = 4; % Downsampling is one of the implementation optimization techniques

%% Generate kernels values for the iOS implementation

% 1. Kernels for the normal, separable filter implementation using discrete
% texture sampling. It generates a separable filter kernel with weights.
discreteTextureSamplingGaussianFilterKernels(kKernelCount, kMinSigma, kMaxSigma);
% 2. Kernels for the bilinear texture sampling optimization technique. 
% It generates a sample pairs with weights and offsets (see docs).
bilinearTextureSamplingGaussianFilterKernels(kKernelCount, kMinSigma, kMaxSigma);

%% Research + Playground

% Filter size, radius and kernel used
fs = filterSize(kMaxSigma);
fr = filterRadius(kMaxSigma)
gaussianFilterKernel = Gaussian2dMatrix(kMaxSigma);
% Test images
testImage1 = readTestImage('test-image-1.png', kDownsamplingFactor);
testImage2 = readTestImage('test-image-2.png', kDownsamplingFactor);
% 1. Normal 2d convolution with 2 passes
filteredTestImage1stPass = imfilter(testImage1, gaussianFilterKernel, 'conv');
filteredTestImage2ndPass = imfilter(filteredTestImage1stPass, gaussianFilterKernel, 'conv'); % 2nd gaussian filter pass (better than a bigger kernel?)
writeTestImage(filteredTestImage2ndPass, 'filtered-camera-image-2d-convolution.png', kDownsamplingFactor);
imshow(filteredTestImage2ndPass);
% 2. Using separable filters, with two one-dimensional Gaussian blurs
horizontalGaussianFilterKernel = HorizontalGaussian2dMatrix(gaussianFilterKernel);
verticalGaussianFilterKernel = VerticalGaussian2dMatrix(gaussianFilterKernel);
filteredTestImage1stPassH = imfilter(testImage1, horizontalGaussianFilterKernel, 'conv');
filteredTestImage1stPassV = imfilter(filteredTestImage1stPassH, verticalGaussianFilterKernel, 'conv');
filteredTestImage2ndPassH = imfilter(filteredTestImage1stPassV, horizontalGaussianFilterKernel, 'conv');
filteredTestImage2ndPassV = imfilter(filteredTestImage2ndPassH, verticalGaussianFilterKernel, 'conv');
writeTestImage(filteredTestImage2ndPass, 'filtered-test-image-separable-filters.png', kDownsamplingFactor);
%imshow(filteredTestImage2ndPassV);
% Random stuff
%Gaussian(0,SIGMA);
%Cook(0,SIGMA,filterRadius(SIGMA));
%cookFilterKernel = Cook2dMatrix(SIGMA);
%filteredTestImage1CookKernel = imfilter(testImage1, cookFilterKernel);
%imshow(filteredTestImage1CookKernel);
%gaussian = fspecial('gaussian', [fs,fs],SIGMA);
%gaussian
%filtered = imfilter(testImage1, gaussian);
%imshow(filtered);
%filteredBetter = imgaussfilt(testImage1, SIGMA);
%imshow(filteredBetter)

%% Utility functions for test images

function dim = readTestImage(imageName, DOWNSAMPLING_FACTOR)
im = imread(imageName);
dim = imresize(im, 1.0/DOWNSAMPLING_FACTOR, 'bilinear');
end

function writeTestImage(dim, imageName, DOWNSAMPLING_FACTOR)
uim = imresize(dim, DOWNSAMPLING_FACTOR, 'bilinear');
imwrite(uim, imageName);
end

%% Filter size, radius

function fs = filterSize(SIGMA)
fs = 2*ceil(2*SIGMA)+1; % or 2*ceil(2*SIGMA)+1
end

function fr = filterRadius(SIGMA)
fr = ceil(filterSize(SIGMA)/2);
end

%% Gaussian and related functions

function g = Gaussian(x, SIGMA)
g = exp(-1 * (x ^ 2)/(2 * (SIGMA ^ 2)))
end

function g2d = Gaussian2d(x, y, SIGMA)
g2d = exp(-1 * ( ((x^2)/(2*(SIGMA^2))) + ((y^2)/(2*(SIGMA^2))) ) );
end

function c = Cook(x, SIGMA, radius) % Truncated gaussian filter with smoother dropoff
if x <= radius
    c = exp(-1 * (x^2)/(2*(SIGMA^2))) - exp(-1 * (radius^2)/(2*(SIGMA^2)))
else
    c = 0;
end
end

function c2d = Cook2d(x, y, SIGMA, radius) % Truncated gaussian filter with smoother dropoff
if x <= radius && y <= radius
c2d = exp(-1 * ( ((x^2)/(2*(SIGMA^2))) + ((y^2)/(2*(SIGMA^2))) ) ) - exp(-1 * (radius^2)/(2*(SIGMA^2)));
else
c2d = 0;
end
end

function g2dm = Gaussian2dMatrix(SIGMA)
fs = filterSize(SIGMA);
fr = filterRadius(SIGMA);
g2dm = zeros(fs, fs);
for x = 1:fs
    for y = 1:fs
        g2dm(y,x) = Gaussian2d(x-fr, y-fr, SIGMA);
    end
end
g2dm = (g2dm / sum(sum(g2dm))); % normalize matrix so that the final weights will sum to 1
end

function hg2dm = HorizontalGaussian2dMatrix(g2dm)
[m,n] = size(g2dm);
hg2dm = zeros(m, n);
for x = 1:m
    hg2dm(1,x) = g2dm(x, x);
end
hg2dm = (hg2dm.^0.5); % sqrt elements so horizontal x vertical = gaussian 2d matrix weights
end

function vg2dm = VerticalGaussian2dMatrix(g2dm)
[m,n] = size(g2dm);
vg2dm = zeros(m, n);
for y = 1:n
    vg2dm(y,1) = g2dm(y, y);
end
vg2dm = (vg2dm.^0.5); % sqrt elements so horizontal x vertical = gaussian 2d matrix weights
end

function c2dm = Cook2dMatrix(SIGMA)
fs = filterSize(SIGMA);
fr = filterRadius(SIGMA);
c2dm = zeros(fs, fs);
for x = 1:fs
    for y = 1:fs
        c2dm(y,x) = Cook2d(x-fr, y-fr, SIGMA, fr);
    end
end
c2dm = (c2dm / sum(sum(c2dm))) % normalize matrix so that the final weights will sum to 1
end

%% Kernel generation for 1) separable gaussian blur filter with discrete sampling

function outputStr = discreteTextureSamplingGaussianFilterWeights(t, minSigma, maxSigma)
sigma = lerp(t, minSigma, maxSigma);
gaussianFilterKernel = Gaussian2dMatrix(sigma);
[m,n] = size(gaussianFilterKernel);
weights = zeros(1,m);
for x = 1:m
    weights(1,x) = gaussianFilterKernel(x, x);
end
weights = (weights.^0.5); % sqrt elements so horizontal x vertical = gaussian 2d matrix weights
weightsStr = sprintf('%f, ' , weights);
weightsStr = weightsStr(1:end-1);
outputStr = sprintf('{ /* t */ %f, /* sigma */ %f, /* size */ %d, /* weights */ %s },', t, sigma, m, weightsStr);
end

function discreteTextureSamplingGaussianFilterKernelsStr = discreteTextureSamplingGaussianFilterKernels(kernelCount, minSigma, maxSigma)
discreteTextureSamplingGaussianFilterKernelsStr = '';
for t = 0:(kernelCount-1)
    discreteTextureSamplingGaussianFilterKernelsStr = sprintf('%s\n%s', discreteTextureSamplingGaussianFilterKernelsStr, discreteTextureSamplingGaussianFilterWeights(t/(kernelCount-1), minSigma, maxSigma));
end
discreteTextureSamplingGaussianFilterKernelsStr
end

%% Kernel generation for 2) bilinear texture sampling implementation

function outputStr = bilinearTextureSamplingGaussianFilterWeightsAndOffsets(t, minSigma, maxSigma)
sigma = smoothStep(t, minSigma, maxSigma);
maxFilterSize = filterSize(maxSigma);
gaussianFilterKernel = Gaussian2dMatrix(sigma);
[m,n] = size(gaussianFilterKernel);
weights = zeros(1,m);
for x = 1:m
    weights(1,x) = gaussianFilterKernel(x, x);
end
weights = (weights.^0.5);

% Numbers of samples needed for a kernel with size m
% For each sample we need to calculate a weight and offset
% Using the bilinear texture filtering available in the GPU we reduce 
% the total number of texture reads from m to ceil(m/2)
btsSamples = floor(floor(m/2)/2)+1;
maxBtsSamples = floor(floor(maxFilterSize/2)/2)+1;
btsWeights = zeros(1,maxBtsSamples);
btsWeightsSum = 0;
btsOffsets = zeros(1,maxBtsSamples);

% Start with the edge of the normal gaussian filter kernel towards the center
% The edge weight of the kernel + neighbor 
centerPixel = ceil(m/2); 
currentPixel = m;
neighborPixel = currentPixel - 1;
btsIndex = btsSamples;
while currentPixel > centerPixel 
    neighborPixel = currentPixel - 1;
    % Skip the the center pixel and neighbor, the weight of both will be calculated at the end
    if neighborPixel ~= centerPixel 
        weightCurrentPixel = weights(1,currentPixel);
        weightNeighborPixel = weights(1,neighborPixel);
        % Sum weights of current + neighbor 
        btsWeights(1,btsIndex) = weightCurrentPixel + weightNeighborPixel;
        btsWeightsSum = btsWeightsSum + btsWeights(1,btsIndex);
        % The offset value is interpolated based on the weight of both
        btsOffsets(1,btsIndex) = (neighborPixel-centerPixel) + (weightCurrentPixel/(weightCurrentPixel + weightNeighborPixel));
        % Move to next sample, closer to the center pixel
        btsIndex = btsIndex - 1;
    end
    currentPixel = currentPixel - 2; % Skip neighbor pixel
end

% calculate weight of the center pixel. The total must be 0.5 for
% left/right side, so the center pixel weight = 0.5 - sum
btsWeights(1,1) = 0.5 - btsWeightsSum;

% calculate offset of the center pixel if it also includes the neighbors
% For example, for n=5 it's only the center pixel but for n=7 it include 
% the neighbors. This is we calculate a new set of weights and sampling 
% offsets from pairs of neighboring pixels, starting from the edge of the 
% original kernel
if neighborPixel == centerPixel
   weightCenterPixel = weights(1,centerPixel);
   weightNeighborPixel = weights(1,centerPixel+1);
   % In this case the center pixel is split in 2 samples
   btsOffsets(1,1) = weightNeighborPixel / (weightNeighborPixel + weightCenterPixel/2); 
else
   btsOffsets(1,1) = 0.0; % only the centerPixel
end

weightsStr = sprintf('%f,' , btsWeights);
weightsStr = weightsStr(1:end-1);
offsetsStr = sprintf('%f,' , btsOffsets);
offsetsStr = offsetsStr(1:end-1);
outputStr = sprintf('{ /* t */ %f, /* sigma */ %f, /* size */ %d, /* samples */ %d, /* offsets */ %s, /* weights */ %s },', t, sigma, m, btsSamples, offsetsStr, weightsStr);
end

function bilinearTextureSamplingGaussianFilterKernelsStr = bilinearTextureSamplingGaussianFilterKernels(kernelCount, minSigma, maxSigma)
    bilinearTextureSamplingGaussianFilterKernelsStr = '';
    for t = 0:(kernelCount-1)
        bilinearTextureSamplingGaussianFilterKernelsStr = sprintf('%s\n%s', bilinearTextureSamplingGaussianFilterKernelsStr, bilinearTextureSamplingGaussianFilterWeightsAndOffsets(t/(kernelCount-1), minSigma, maxSigma));
    end
    bilinearTextureSamplingGaussianFilterKernelsStr
end

%% Lerp and easing functions

function lerpValue = lerp(t, min, max)
lerpValue = (1-t)*min + t*max;
end

function expLerpValue = expLerp(t, min, max)
expLerpValue = lerp(t*t, min, max);
end

function easeOutQuadValue = easeOutQuad(t, min, max) 
tSin = sin(t * pi * 0.5);
easeOutQuadValue = (1-tSin)*min + tSin*max;
end

function smoothStepValue = smoothStep(t, min, max)
tst =  t*t * (3 - 2*t)
smoothStepValue = (1 - tst)*min + tst*max;
end

