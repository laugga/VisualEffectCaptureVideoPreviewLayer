/*
 
 MockLAUCaptureVideoPreviewLayerInternal.m
 LAUCaptureVideoPreviewLayer Tests
 
 Copyright (c) 2016 Luis Laugga
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

- (void)setSession:(AVCaptureSession *)session
{
    Log(@"MockLAUCaptureVideoPreviewLayerInternal: Ignoring setSession: call");
}

- (CMSampleBufferRef)sampleBuffer
{
    NSAssert(self.sampleBufferImage != NULL, @"MockLAUCaptureVideoPreviewLayerInternal: sampleBufferImage is nil");
    
    CVPixelBufferRef pixelBuffer = [[self class] pixelBufferFromCGImage:self.sampleBufferImage.CGImage];
    
    CMSampleBufferRef sampleBuffer = NULL;
    
    CMSampleTimingInfo timimgInfo = kCMTimingInfoInvalid;
    
    CMVideoFormatDescriptionRef videoInfo = NULL;
    CMVideoFormatDescriptionCreateForImageBuffer(NULL, pixelBuffer, &videoInfo);
    
    CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault,
                                       pixelBuffer,
                                       true,
                                       NULL,
                                       NULL,
                                       videoInfo,
                                       &timimgInfo,
                                       &sampleBuffer);
    
    return sampleBuffer;
}

+ (CVPixelBufferRef)pixelBufferFromCGImage:(CGImageRef)image
{
    NSAssert(image != NULL, @"MockLAUCaptureVideoPreviewLayerInternal: pixelBufferFromCGImage failed because image is NULL");
    
    size_t width = CGImageGetWidth(image);
    size_t height = CGImageGetHeight(image);
    
    CVPixelBufferRef pixelBuffer = NULL;
    NSDictionary * pixelBufferAttributes = @{ (NSString *)kCVPixelBufferCGImageCompatibilityKey: @YES,
                                              (NSString *)kCVPixelBufferCGBitmapContextCompatibilityKey: @YES };
    
    CVReturn result = CVPixelBufferCreate(NULL, width, height, kCVPixelFormatType_32BGRA, (__bridge CFDictionaryRef)pixelBufferAttributes, &pixelBuffer);
    
    if (result != kCVReturnSuccess) {
        Log(@"MockLAUCaptureVideoPreviewLayerInternal: Failed to create pixelBuffer from image %@", image);
        return NULL;
    }
    
    CIContext * coreImageContext = [CIContext contextWithCGContext:UIGraphicsGetCurrentContext() options:nil];
    [coreImageContext render:[CIImage imageWithCGImage:image] toCVPixelBuffer:pixelBuffer];
    
    return pixelBuffer;
}

@end
