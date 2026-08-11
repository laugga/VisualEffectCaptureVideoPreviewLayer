# LAUCaptureVideoPreviewLayer

## Introduction

LAUCaptureVideoPreviewLayer is a preview layer for the AVCaptureSession with a Metal-based blur filter. You can use it like a AVCaptureVideoPreviewLayer and then dynamically/in real-time apply a blur filter to the video output frames.

It was developed for [Lightmate](https://lightmate.app/ "Lightmate")'s iOS app with the goal of replacing AVFoundation's *AVCaptureVideoPreviewLayer*. This is mainly an R&D project and there are still many optimizations needed before it can be used in a "production" context. This is an attempt to share some of the learnings and components used in the app.

## Requirements and Dependencies

* iOS 17.0 or later
* ARC
* Suported devices: any device with a Metal capable GPU
* Metal / Metal Shading Language

## Using with CocoaPods

Create or edit an existing text file named Podfile in your Xcode project directory:

```ruby
pod "LAUCaptureVideoPreviewLayer", '~> 0.1.0'
```

Install LAUCaptureVideoPreviewLayer in your project:

```bash
$ pod install
```

Open the Xcode workspace instead of the project file when building your project:

```bash
$ open YourProject.xcworkspace
```

Import LAUCaptureVideoPreviewLayer:

```obj-c
#import <LAUCaptureVideoPreviewLayer/LAUCaptureVideoPreviewLayer.h>
```

LAUCaptureVideoPreviewLayer's interface is very similar to AVCaptureVideoPreviewLayer. Here's an example:

```obj-c
// Create your AVCaptureSession
// ...

// Create the session video preview layer from LAUCaptureVideoPreviewLayer
LAUCaptureVideoPreviewLayer * videoPreviewLayer = [[LAUCaptureVideoPreviewLayer alloc] initWithSession:captureSession];

// Change the blur property just like you change opacity
videoPreviewLayer.blur = 1.0f;
```

## Example

The example is a single view application with a AVCaptureSession and a AVCaptureDeviceInput (AVCaptureDevicePositionBack).

![Blur in out example](docs/figures/blur-in-out-example.gif)

__Interactions:__

* Tap to blur-in (animated)
* Pull-down to gradually decrease blur value
* Pause/Resume the capture session (animated)

## Development Notes

__LAUCaptureVideoPreviewLayer vs. AVCaptureVideoPreviewLayer__

LAUCaptureVideoPreviewLayer could be used as a drop-in replacement for AVCaptureVideoPreviewLayer. Our intention during the development was to copy and mimic as much as possible AVCaptureVideoPreviewLayer's interface and behavior. However, under the hood that is totally different. To start AVCaptureVideoPreviewLayer is Apple's own preview layer with access to unknown APIs. If you inspect an AVCaptureSession's connections you'll notice AVCaptureVideoPreviewLayer is used as an output (just like AVCaptureVideoDataOutput, for example).

In order to make LAUCaptureVideoPreviewLayer work we need to add a AVCaptureVideoDataOutput to the existing AVCaptureSession. We then use the _captureOutput:didOutputSampleBuffer:fromConnection:_ delegate method to render each frame and apply the blur filter. If you need to use a AVCaptureVideoDataOutput yourself it's also possible. In that case LAUCaptureVideoPreviewLayer will detect if an existing AVCaptureVideoDataOutput is already added to the session's outputs and then _hijack_ it. Your _captureOutput:didOutputSampleBuffer:fromConnection:_ delegate method will then be called from LAUCaptureVideoPreviewLayer.

Remember, LAUCaptureVideoPreviewLayer is experimental. Please report any issues you find.

__Gaussian Blur Implementation__

1. Separable filters
2. Bilinear interpolated texture sampling
3. Downsampling
4. Dynamic texture lookup

## References

[Real-Time Rendering, 3rd Edition, 10.9 Image Processing (p.468-472)](http://www.realtimerendering.com)

[Intel, An investigation of fast real-time GPU-based image blur algorithms](https://software.intel.com/en-us/blogs/2014/07/15/an-investigation-of-fast-real-time-gpu-based-image-blur-algorithms)

[GPU Gems 3, Chapter 40. Incremental Computation of the Gaussian](http://http.developer.nvidia.com/GPUGems3/gpugems3_ch40.html)

[Rastergrid, Efficient Gaussian blur with linear sampling](http://rastergrid.com/blog/2010/09/efficient-gaussian-blur-with-linear-sampling/)

[Xissburg, Faster Gaussian Blur in GLSL](http://xissburg.com/faster-gaussian-blur-in-glsl/)
