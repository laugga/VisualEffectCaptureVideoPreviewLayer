/*
 
 LAUCaptureVideoPreviewLayerInternal.h
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

#import <AVFoundation/AVFoundation.h>

@protocol LAUCaptureVideoPreviewLayerInternalDelegate;

@interface LAUCaptureVideoPreviewLayerInternal : NSObject

/*!
 @property session
 @abstract
 The AVCaptureSession instance being previewed by the receiver.
 
 @discussion
 The session is retained by the preview layer.
 */
@property (nonatomic, strong) AVCaptureSession * session;

/*!
 @property sampleBuffer
 @abstract
 The CMSampleBufferRef sample buffer being currently displayed
 */
@property (nonatomic, readonly) CMSampleBufferRef sampleBuffer;

/*!
 @property sessionIsRunning
 @abstract
 YES if the session is running. NO for all other possible states:
 RuntimeError, Interrupted, Stopped.
 */
@property (nonatomic, readonly) BOOL sessionIsRunning;

/*!
 @property delegate
 @abstract
 Informs the delegate object about state changes in the capture pipeline.
 */
@property (nonatomic, weak) id<LAUCaptureVideoPreviewLayerInternalDelegate> delegate;

@end

@protocol LAUCaptureVideoPreviewLayerInternalDelegate <NSObject>

- (void)captureVideoPreviewLayerInternal:(LAUCaptureVideoPreviewLayerInternal *)internal sessionDidStopRunning:(AVCaptureSession *)session;
- (void)captureVideoPreviewLayerInternal:(LAUCaptureVideoPreviewLayerInternal *)internal sessionDidStartRunning:(AVCaptureSession *)session;

@end
