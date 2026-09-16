/*

 MockLAUCaptureVideoPreviewLayerInternal.m
 LAUCaptureVideoPreviewLayerExample

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

#warning "Objective-C — needs to be refactored and re-written in Swift"

#import "MockLAUCaptureVideoPreviewLayerInternal.h"

@implementation MockLAUCaptureVideoPreviewLayerInternal
{
    CVPixelBufferRef _pixelBuffer;
    CMSampleBufferRef _sampleBuffer;
}

static size_t const kMockPixelBufferWidth = 1280;
static size_t const kMockPixelBufferHeight = 720;

- (void)dealloc
{
    if (_sampleBuffer)
    {
        CFRelease(_sampleBuffer);
    }

    if (_pixelBuffer)
    {
        CVPixelBufferRelease(_pixelBuffer);
    }
}

- (void)setSession:(AVCaptureSession *)session
{
    NSLog(@"MockLAUCaptureVideoPreviewLayerInternal: Ignoring setSession: call");
}

- (CMSampleBufferRef)sampleBuffer
{
    // The same buffer is handed out on every call, the preview layer does not take
    // ownership of it and a new one per frame would leak
    if (_sampleBuffer)
    {
        return _sampleBuffer;
    }

    _pixelBuffer = [self newPixelBuffer];

    if (!_pixelBuffer)
    {
        return NULL;
    }

    CMSampleTimingInfo timingInfo = kCMTimingInfoInvalid;
    CMVideoFormatDescriptionRef videoInfo = NULL;

    CMVideoFormatDescriptionCreateForImageBuffer(NULL, _pixelBuffer, &videoInfo);
    CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault,
                                       _pixelBuffer,
                                       true,
                                       NULL,
                                       NULL,
                                       videoInfo,
                                       &timingInfo,
                                       &_sampleBuffer);

    if (videoInfo)
    {
        CFRelease(videoInfo);
    }

    return _sampleBuffer;
}

/*!
 Draws a colour grid, so that the blur is easy to see without a capture device.
 */
- (CVPixelBufferRef)newPixelBuffer
{
    CVPixelBufferRef pixelBuffer = NULL;
    NSDictionary * pixelBufferAttributes = @{ (NSString *)kCVPixelBufferCGBitmapContextCompatibilityKey: @YES,
                                              (NSString *)kCVPixelBufferMetalCompatibilityKey: @YES };

    CVReturn result = CVPixelBufferCreate(NULL, kMockPixelBufferWidth, kMockPixelBufferHeight, kCVPixelFormatType_32BGRA, (__bridge CFDictionaryRef)pixelBufferAttributes, &pixelBuffer);

    if (result != kCVReturnSuccess)
    {
        NSLog(@"MockLAUCaptureVideoPreviewLayerInternal: Failed to create the pixel buffer (error %d)", result);
        return NULL;
    }

    CVPixelBufferLockBaseAddress(pixelBuffer, 0);

    CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
    CGContextRef bitmapContext = CGBitmapContextCreate(CVPixelBufferGetBaseAddress(pixelBuffer),
                                                       kMockPixelBufferWidth,
                                                       kMockPixelBufferHeight,
                                                       8,
                                                       CVPixelBufferGetBytesPerRow(pixelBuffer),
                                                       colorspace,
                                                       kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);

    NSUInteger const columns = 8;
    NSUInteger const rows = 5;
    CGFloat const cellWidth = kMockPixelBufferWidth / (CGFloat)columns;
    CGFloat const cellHeight = kMockPixelBufferHeight / (CGFloat)rows;

    for (NSUInteger row = 0; row < rows; ++row)
    {
        for (NSUInteger column = 0; column < columns; ++column)
        {
            CGFloat hue = (row * columns + column) / (CGFloat)(rows * columns);
            UIColor * color = [UIColor colorWithHue:hue saturation:0.85 brightness:0.95 alpha:1.0];

            CGContextSetFillColorWithColor(bitmapContext, color.CGColor);
            CGContextFillRect(bitmapContext, CGRectMake(column * cellWidth + 8, row * cellHeight + 8, cellWidth - 16, cellHeight - 16));
        }
    }

    CGContextRelease(bitmapContext);
    CGColorSpaceRelease(colorspace);

    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);

    return pixelBuffer;
}

- (void)simulateCaptureSessionDidStartRunningNotification
{
    if ([self.delegate respondsToSelector:@selector(captureVideoPreviewLayerInternal:sessionDidStartRunning:)]) {
        [self.delegate captureVideoPreviewLayerInternal:self sessionDidStartRunning:nil];
    }
}

- (void)simulateCaptureSessionDidStopRunningNotification
{
    if ([self.delegate respondsToSelector:@selector(captureVideoPreviewLayerInternal:sessionDidStopRunning:)]) {
        [self.delegate captureVideoPreviewLayerInternal:self sessionDidStopRunning:nil];
    }
}

@end
