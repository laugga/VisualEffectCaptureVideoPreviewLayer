//
//  LAUCaptureVideoPreviewLayerUnitTests.m
//  LAUCaptureVideoPreviewLayerUnitTests
//
//  Created by Luis Laugga on 9/20/16.
//  Copyright © 2016 Luis Laugga. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "UIImage+Compare.h"

#import "LAUCaptureVideoPreviewLayer.h"
#import "MockLAUCaptureVideoPreviewLayerInternal.h"

@interface LAUCaptureVideoPreviewLayerTests : XCTestCase
{
    LAUCaptureVideoPreviewLayer * videoPreviewLayer;
    MockLAUCaptureVideoPreviewLayerInternal * mockLAUCaptureVideoPreviewLayerInternal;
}
@end

@implementation LAUCaptureVideoPreviewLayerTests

- (void)setUp {
    [super setUp];
    
    // Create the session video preview layer
    videoPreviewLayer = [[LAUCaptureVideoPreviewLayer alloc] initWithSession:nil];
    [videoPreviewLayer setBackgroundColor:[[UIColor blackColor] CGColor]];
    [videoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill]; // fill the layer
    
    // Inject the mock object for LAUCaptureVideoPreviewLayerInternal
    mockLAUCaptureVideoPreviewLayerInternal = [MockLAUCaptureVideoPreviewLayerInternal new];
    mockLAUCaptureVideoPreviewLayerInternal.sampleBufferImage = [UIImage imageNamed:@"source-image.png" inBundle:SWIFTPM_MODULE_BUNDLE compatibleWithTraitCollection:nil];
    [videoPreviewLayer setInternal:mockLAUCaptureVideoPreviewLayerInternal];
    
    // Set bounds and draw once
    videoPreviewLayer.bounds = CGRectMake(0, 0, 375, 667);
    [videoPreviewLayer layoutIfNeeded];
    [videoPreviewLayer performSelectorOnMainThread:@selector(drawPixelBuffer:) withObject:nil waitUntilDone:YES];
    [videoPreviewLayer setBlur:1.0];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testSourceImageIsNotNil {
    
    UIImage * sourceImage = [UIImage imageFromLayer:videoPreviewLayer];
    
    XCTAssertNotNil(sourceImage, @"Image is nil");

    CGFloat similarity = [sourceImage similarityWithImage:sourceImage];
    
    XCTAssertTrue(similarity == 0.0f, @"Images must be the same");
}

- (void)testRenderedImageSimilarityWithTargetImage {
    
    UIImage * targetImage1 = [UIImage imageNamed:@"target-image-12px-radius.png" inBundle:SWIFTPM_MODULE_BUNDLE compatibleWithTraitCollection:nil];
    UIImage * targetImage2 = [UIImage imageNamed:@"target-image-36px-radius.png" inBundle:SWIFTPM_MODULE_BUNDLE compatibleWithTraitCollection:nil];
    UIImage * targetImage3 = [UIImage imageNamed:@"target-image-48px-radius.png" inBundle:SWIFTPM_MODULE_BUNDLE compatibleWithTraitCollection:nil];
    
    UIImage * renderedImage1 = [UIImage imageFromLayer:videoPreviewLayer];
    
    CGFloat similarity1 = [renderedImage1 similarityWithImage:targetImage1];
    CGFloat similarity2 = [renderedImage1 similarityWithImage:targetImage2];
    CGFloat similarity3 = [renderedImage1 similarityWithImage:targetImage3];
    
    NSLog(@"*** Similarity between rendered image and reference image 1 is %f ***", similarity1);
    NSLog(@"*** Similarity between rendered image and reference image 2 is %f ***", similarity2);
    NSLog(@"*** Similarity between rendered image and reference image 3 is %f ***", similarity3);
    
    XCTAssertTrue(similarity2 < 0.1f, @"For Radius = 36px the images must be the similar within 0.1 tolerance");
    XCTAssertTrue(similarity3 < 0.08f, @"For Radius = 48px the images must be the similar within 0.08 tolerance");
}

- (void)testRenderedImageSimilarityWithAnotherRenderedImage {
    
    UIImage * renderedImage1 = [UIImage imageFromLayer:videoPreviewLayer];
    UIImage * renderedImage2 = [UIImage imageFromLayer:videoPreviewLayer];
    
    CGFloat similarity = [renderedImage1 similarityWithImage:renderedImage2];
  
    XCTAssertEqual(similarity, 0.0);
}

- (void)testRenderPerformance {

    [self measureBlock:^{
        UIImage * renderedImage = [UIImage imageFromLayer:videoPreviewLayer];
        XCTAssertNotNil(renderedImage, @"renderedImage is nil");
    }];
}

@end
