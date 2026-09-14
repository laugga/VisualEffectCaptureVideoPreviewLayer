/*
 
 CameraPreviewView.m
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

#import "CameraPreviewView.h"

@implementation CameraPreviewView

static CGFloat const kLongPressBeganLocationLayerWidth = 80.0f;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        // Long press gesture used to blur-in/out the preview
        UILongPressGestureRecognizer * longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(userDidLongPress:)];
        longPressGestureRecognizer.minimumPressDuration = 0.001;
        [self addGestureRecognizer:longPressGestureRecognizer];
        
        // Debug layer used to show the initial tap location of the long press gesture recognizer
        _longPressBeganLocationLayer = [[CALayer alloc] init];
        _longPressBeganLocationLayer.bounds = CGRectMake(0, 0, kLongPressBeganLocationLayerWidth, kLongPressBeganLocationLayerWidth);
        _longPressBeganLocationLayer.cornerRadius = kLongPressBeganLocationLayerWidth/2.0f;
        _longPressBeganLocationLayer.anchorPoint = CGPointMake(0.5, 0.5);
        _longPressBeganLocationLayer.backgroundColor = [[UIColor whiteColor] CGColor];
        _longPressBeganLocationLayer.opacity = 0.9;
        _longPressBeganLocationLayer.hidden = YES;
        [self.layer addSublayer:_longPressBeganLocationLayer];
    }
    
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    // IMPORTANT
    _videoPreviewLayer.frame = self.bounds;
}

#pragma mark -
#pragma mark Preview Layer

- (void)setCaptureSession:(id)captureSession
{
    if (captureSession)
    {
        // Create the session video preview layer
        LAUCaptureVideoPreviewLayer * videoPreviewLayer = [[LAUCaptureVideoPreviewLayer alloc] initWithSession:captureSession];
        [videoPreviewLayer setBackgroundColor:[self.backgroundColor CGColor]];
        [videoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill]; // fill the layer

        [self setVideoPreviewLayer:videoPreviewLayer];
    }
    else
    {
        // Remove preview layer from superview
        [self setVideoPreviewLayer:nil];
    }
}

- (void)setVideoPreviewLayer:(LAUCaptureVideoPreviewLayer *)videoPreviewLayer
{
    if (videoPreviewLayer)
    {
        _videoPreviewLayer = videoPreviewLayer;
        
        [self.layer setMasksToBounds:YES];
        [self.layer insertSublayer:_videoPreviewLayer below:_longPressBeganLocationLayer];
    }
    else
    {
        [_videoPreviewLayer removeFromSuperlayer];
        _videoPreviewLayer = nil;
    }
}

#pragma mark -
#pragma mark Interactions

- (void)userDidLongPress:(UITapGestureRecognizer *)sender
{
    static CGPoint beganLocation;
    
    if (sender.state == UIGestureRecognizerStateBegan)
    {
        beganLocation = [sender locationInView:self];
        
        // Switch to blur = 1.0 when user presses
        //_videoPreviewLayer.blur = 1.0;
        [_videoPreviewLayer setBlur:1.0 animated:YES];
        
        // Show debug view
        [CATransaction begin];
        [CATransaction setValue: (id) kCFBooleanTrue forKey: kCATransactionDisableActions];
        _longPressBeganLocationLayer.position = [sender locationInView:self];
        _longPressBeganLocationLayer.hidden = NO;
        [CATransaction commit];
    }
    else if (sender.state == UIGestureRecognizerStateChanged)
    {
        CGPoint changedLocation = [sender locationInView:self];
        CGFloat offsetPercent = (beganLocation.y - changedLocation.y)/100.0f;
        CGFloat blur = 1.0f + offsetPercent;
        
        // Set a new blur value
        [_videoPreviewLayer setBlur:blur animated:YES];
    }
    else if (sender.state == UIGestureRecognizerStateEnded || sender.state == UIGestureRecognizerStateFailed)
    {
        // Turn blur off when user stops pressing
        //_videoPreviewLayer.blur = 0.0f;
        [_videoPreviewLayer setBlur:0.0 animated:YES];
        
        // Hide debug view
        _longPressBeganLocationLayer.hidden = YES;
    }
}

@end
