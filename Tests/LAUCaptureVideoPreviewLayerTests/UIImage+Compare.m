/*
 
 UIImage+Compare.m
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

#import "UIImage+Compare.h"

@implementation UIImage (Compare)

+ (UIImage *)imageFromLayer:(CALayer *)layer
{
    CGRect bounds = layer.bounds;
    
    NSAssert(CGRectGetWidth(bounds) > 0, @"Layer %@ width is zero", layer);
    NSAssert(CGRectGetHeight(bounds) > 0, @"Layer %@ height is zero", layer);
    
    UIGraphicsBeginImageContextWithOptions(bounds.size, NO, 0);
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    NSAssert(context != NULL, @"Invalid context for layer %@", layer);
    
    CGContextSaveGState(context);
    
    [layer layoutIfNeeded];
    [layer renderInContext:context];
    
    CGContextRestoreGState(context);
    
    UIImage * imageFromLayer = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return imageFromLayer;
}

- (CGFloat)similarityWithImage:(UIImage *)image
{
    NSAssert(image, @"image is nil");
    
    CGImageRef self_cgImage = self.CGImage;
    CGImageRef cgImage = image.CGImage;
    
    CGSize self_imageSize = CGSizeMake(CGImageGetWidth(self_cgImage), CGImageGetHeight(self_cgImage));
    CGSize imageSize = CGSizeMake(CGImageGetWidth(cgImage), CGImageGetHeight(cgImage));
    
    size_t self_imageSizeBytes = self_imageSize.height * CGImageGetBytesPerRow(self_cgImage);
    size_t imageSizeBytes = imageSize.height * CGImageGetBytesPerRow(cgImage);
    
    void * self_imagePixelData = calloc(self_imageSizeBytes, 1);
    void * imagePixelData = calloc(imageSizeBytes, 1);
    
    NSAssert(self_imagePixelData, @"self_imageData is NULL");
    NSAssert(imagePixelData, @"imageData is NULL");
    
    CGContextRef self_imageContext = CGBitmapContextCreate(self_imagePixelData,
                                                           self_imageSize.width,
                                                           self_imageSize.height,
                                                           CGImageGetBitsPerComponent(self_cgImage),
                                                           CGImageGetBytesPerRow(self_cgImage),
                                                           CGImageGetColorSpace(self_cgImage),
                                                           (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    
    CGContextRef imageContext = CGBitmapContextCreate(imagePixelData,
                                                      imageSize.width,
                                                      imageSize.height,
                                                      CGImageGetBitsPerComponent(cgImage),
                                                      CGImageGetBytesPerRow(cgImage),
                                                      CGImageGetColorSpace(cgImage),
                                                      (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    
    NSAssert(self_imageContext, @"self_imageContext is NULL");
    NSAssert(imageContext, @"imageContext is NULL");
    
    CGContextDrawImage(self_imageContext, CGRectMake(0, 0, self_imageSize.width, self_imageSize.height), self_cgImage);
    CGContextDrawImage(imageContext, CGRectMake(0, 0, imageSize.width, imageSize.height), cgImage);
    
    CGContextRelease(self_imageContext);
    CGContextRelease(imageContext);
    
    // Compare each pixel color
    // The comparison of each pixel contributes to the final similarity score
    CGFloat comparedPixelCount = 0; // Increment for every pixel compared
    CGFloat comparedPixelSum = 0; // Total sum of all pixel compare operations
    
    size_t self_imagePixelCount = self_imageSize.width * self_imageSize.height;
    size_t imagePixelCount = imageSize.width * imageSize.height;
    
    CGImagePixelData * self_imagePixel = self_imagePixelData;
    CGImagePixelData * imagePixel = imagePixelData;
    
    while (comparedPixelCount < self_imagePixelCount && comparedPixelCount < imagePixelCount)
    {
        // 0 they are the same rgb colors, 1 they are totally different colors
        comparedPixelSum += CGImagePixelDataCompare(*self_imagePixel, *imagePixel);
        comparedPixelCount += 1.0;
        
        ++self_imagePixel;
        ++imagePixel;
    }

    free(self_imagePixelData);
    free(imagePixelData);
    
    return comparedPixelSum/comparedPixelCount;
}

typedef union {
    uint32_t raw;
    unsigned char bytes[4];
    struct {
        char red;
        char green;
        char blue;
        char alpha;
    } __attribute__ ((packed)) rgba;
} CGImagePixelData;

float CGImagePixelDataCompare(CGImagePixelData cgImagePixelData1, CGImagePixelData cgImagePixelData2)
{
    float redCmp = ((float)abs(cgImagePixelData1.rgba.red - cgImagePixelData2.rgba.red)) / 255.0f;
    float greenCmp = ((float)abs(cgImagePixelData1.rgba.green - cgImagePixelData2.rgba.green)) / 255.0f;
    float blueCmp = ((float)abs(cgImagePixelData1.rgba.blue - cgImagePixelData2.rgba.blue)) / 255.0f;
    
    return (redCmp + greenCmp + blueCmp) / 3.0f;
}

@end
