/*
 
 LAUCaptureVideoPreviewLayer.h
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

#warning "Objective-C — needs to be refactored and re-written in Swift"

#import <UIKit/UIKit.h>

#import <AVFoundation/AVBase.h>
#import <QuartzCore/QuartzCore.h>
#import <QuartzCore/CAMetalLayer.h>
#import <AVFoundation/AVCaptureSession.h>
#import <AVFoundation/AVAnimation.h>

@class AVMetadataObject;
@class LAUCaptureVideoPreviewLayerInternal;

/*!
 @class LAUCaptureVideoPreviewLayer
 @abstract
 A CoreAnimation layer subclass for previewing the visual output of an AVCaptureSession.

 @discussion
 An AVCaptureVideoPreviewLayer instance is a subclass of CALayer and is therefore
 suitable for insertion in a layer hierarchy as part of a graphical interface.
 One creates an AVCaptureVideoPreviewLayer instance with the capture session to be
 previewed, using +layerWithSession: or -initWithSession:.  Using the @"videoGravity"
 property, one can influence how content is viewed relative to the layer bounds.  On
 some hardware configurations, the orientation of the layer can be manipulated using
 @"orientation" and @"mirrored".

 The receiver renders the video frames with Metal. It is a CAMetalLayer subclass
 and owns the MTLDevice, the command queue and the render pipeline states used to
 draw and filter each frame.
 */
__TVOS_PROHIBITED
@interface LAUCaptureVideoPreviewLayer : CAMetalLayer
{
@private
    LAUCaptureVideoPreviewLayerInternal * _internal;
}

#if DEBUG
/*!
 @property internal
 @abstract
 This property can be used to inject a specific LAUCaptureVideoPreviewLayerInternal instance.
 
 @discussion
 Only available for testing purposes. Needed to, for example, render a specific sample buffer.
 */
@property (nonatomic, strong) LAUCaptureVideoPreviewLayerInternal * internal;
#endif

/*!
 @property blur
 @abstract
 The intensity of the gaussian blur effect. If the value is 0 no blur effect is
 applied to the preview layer.
 
 @discussion
 Internally the layer has multiple gaussian blur kernels with different radius
 and std. deviation. 
 */
@property (nonatomic, readwrite) CGFloat blur; // [0,1]

/*!
 @method setBlur:animated:
 @abstract
 Changes the blur effect of the LAUCaptureVideoPreviewLayer with an animated
 transition from the current value to the specified value.
 
 @param blur
 The blur intensity value, from 0.0 to 1.0.
 @param animated
 YES to enable the animated transition.
 */
- (void)setBlur:(CGFloat)blur animated:(BOOL)animated;

/*!
 @method layerWithSession:
 @abstract
 Creates an AVCaptureVideoPreviewLayer for previewing the visual output of the
 specified AVCaptureSession.
 
 @param session
 The AVCaptureSession instance to be previewed.
 @result
 A newly initialized AVCaptureVideoPreviewLayer instance.
 */
+ (instancetype)layerWithSession:(AVCaptureSession *)session;

/*!
 @method initWithSession:
 @abstract
 Creates an AVCaptureVideoPreviewLayer for previewing the visual output of the
 specified AVCaptureSession.
 
 @param session
 The AVCaptureSession instance to be previewed.
 @result
 A newly initialized AVCaptureVideoPreviewLayer instance.
 */
- (instancetype)initWithSession:(AVCaptureSession *)session;

/*!
 @method layerWithSessionWithNoConnection:
 @abstract
 Creates an AVCaptureVideoPreviewLayer for previewing the visual output of the
 specified AVCaptureSession, but creates no connections to any of the session's
 eligible video inputs.  Only use this initializer if you intend to manually
 form a connection between a desired AVCaptureInputPort and the receiver using
 AVCaptureSession's -addConnection: method.
 
 @param session
 The AVCaptureSession instance to be previewed.
 @result
 A newly initialized AVCaptureVideoPreviewLayer instance.
 */
+ (instancetype)layerWithSessionWithNoConnection:(AVCaptureSession *)session;

/*!
 @method initWithSessionWithNoConnection:
 @abstract
 Creates an AVCaptureVideoPreviewLayer for previewing the visual output of the
 specified AVCaptureSession, but creates no connections to any of the session's
 eligible video inputs.  Only use this initializer if you intend to manually
 form a connection between a desired AVCaptureInputPort and the receiver using
 AVCaptureSession's -addConnection: method.
 
 @param session
 The AVCaptureSession instance to be previewed.
 @result
 A newly initialized AVCaptureVideoPreviewLayer instance.
 */
- (instancetype)initWithSessionWithNoConnection:(AVCaptureSession *)session;

/*!
 @property session
 @abstract
 The AVCaptureSession instance being previewed by the receiver.
 
 @discussion
 The session is retained by the preview layer.
 */
@property (nonatomic, retain) AVCaptureSession *session;

/*!
 method setSessionWithNoConnection:
 @abstract
 Attaches the receiver to a given session without implicitly forming a
 connection to the first eligible video AVCaptureInputPort.  Only use this
 setter if you intend to manually form a connection between a desired
 AVCaptureInputPort and the receiver using AVCaptureSession's -addConnection:
 method.
 
 @discussion
 The session is retained by the preview layer.
 */
- (void)setSessionWithNoConnection:(AVCaptureSession *)session;

/*!
 @property connection
 @abstract
 The AVCaptureConnection instance describing the AVCaptureInputPort to which
 the receiver is connected.
 
 @discussion
 When calling initWithSession: or setSession: with a valid AVCaptureSession instance,
 a connection is formed to the first eligible video AVCaptureInput.  If the receiver
 is detached from a session, the connection property becomes nil.
 */
@property (nonatomic, readonly) AVCaptureConnection *connection;

/*!
 @property videoGravity
 @abstract
 A string defining how the video is displayed within an AVCaptureVideoPreviewLayer bounds rect.
 
 @discussion
 Options are AVLayerVideoGravityResize, AVLayerVideoGravityResizeAspect
 and AVLayerVideoGravityResizeAspectFill. AVLayerVideoGravityResizeAspect is default.
 See <AVFoundation/AVAnimation.h> for a description of these options.
 */
@property (copy) NSString *videoGravity;

/*!
 @method captureDevicePointOfInterestForPoint:
 @abstract
 Converts a point in layer coordinates to a point of interest in the coordinate space of the capture device providing
 input to the layer.
 
 @param pointInLayer
 A CGPoint in layer coordinates.
 
 @result
 A CGPoint in the coordinate space of the capture device providing input to the layer.
 
 @discussion
 AVCaptureDevice pointOfInterest is expressed as a CGPoint where {0,0} represents the top left of the picture area,
 and {1,1} represents the bottom right on an unrotated picture.  This convenience method converts a point in
 the coordinate space of the receiver to a point of interest in the coordinate space of the AVCaptureDevice providing
 input to the receiver.  The conversion takes frameSize and videoGravity into consideration.
 */
- (CGPoint)captureDevicePointOfInterestForPoint:(CGPoint)pointInLayer;

/*!
 @method pointForCaptureDevicePointOfInterest:
 @abstract
 Converts a point of interest in the coordinate space of the capture device providing
 input to the layer to a point in layer coordinates.
 
 @param captureDevicePointOfInterest
 A CGPoint in the coordinate space of the capture device providing input to the layer.
 
 @result
 A CGPoint in layer coordinates.
 
 @discussion
 AVCaptureDevice pointOfInterest is expressed as a CGPoint where {0,0} represents the top left of the picture area,
 and {1,1} represents the bottom right on an unrotated picture.  This convenience method converts a point in
 the coordinate space of the AVCaptureDevice providing input to the coordinate space of the receiver.  The conversion
 takes frame size and videoGravity into consideration.
 */
- (CGPoint)pointForCaptureDevicePointOfInterest:(CGPoint)captureDevicePointOfInterest;

/*!
 @method metadataOutputRectOfInterestForRect:
 @abstract
	Converts a rectangle in layer coordinates to a rectangle of interest in the coordinate space of an AVCaptureMetadataOutput
	whose capture device is providing input to the layer.
 
 @param rectInLayerCoordinates
	A CGRect in layer coordinates.
 
 @result
	A CGRect in the coordinate space of the metadata output whose capture device is providing input to the layer.
 
 @discussion
	AVCaptureMetadataOutput rectOfInterest is expressed as a CGRect where {0,0} represents the top left of the picture area,
	and {1,1} represents the bottom right on an unrotated picture.  This convenience method converts a rectangle in
	the coordinate space of the receiver to a rectangle of interest in the coordinate space of an AVCaptureMetadataOutput
	whose AVCaptureDevice is providing input to the receiver.  The conversion takes frame size and videoGravity into consideration.
 */
- (CGRect)metadataOutputRectOfInterestForRect:(CGRect)rectInLayerCoordinates;

/*!
 @method rectForMetadataOutputRectOfInterest:
 @abstract
	Converts a rectangle of interest in the coordinate space of an AVCaptureMetadataOutput whose capture device is
	providing input to the layer to a rectangle in layer coordinates.
 
 @param rectInMetadataOutputCoordinates
	A CGRect in the coordinate space of the metadata output whose capture device is providing input to the layer.
 
 @result
	A CGRect in layer coordinates.
 
 @discussion
	AVCaptureMetadataOutput rectOfInterest is expressed as a CGRect where {0,0} represents the top left of the picture area,
	and {1,1} represents the bottom right on an unrotated picture.  This convenience method converts a rectangle in
	the coordinate space of an AVCaptureMetadataOutput whose AVCaptureDevice is providing input to the coordinate space of the
	receiver.  The conversion takes frame size and videoGravity into consideration.
 */
- (CGRect)rectForMetadataOutputRectOfInterest:(CGRect)rectInMetadataOutputCoordinates;

/*!
 @method transformedMetadataObjectForMetadataObject:
 @abstract
 Converts an AVMetadataObject's visual properties to layer coordinates.
 
 @param metadataObject
 An AVMetadataObject originating from the same AVCaptureInput as the preview layer.
 
 @result
 An AVMetadataObject whose properties are in layer coordinates.
 
 @discussion
 AVMetadataObject bounds may be expressed as a rect where {0,0} represents the top left of the picture area,
 and {1,1} represents the bottom right on an unrotated picture.  Face metadata objects likewise express
 yaw and roll angles with respect to an unrotated picture.  -transformedMetadataObjectForMetadataObject:
	converts the visual properties in the coordinate space of the supplied AVMetadataObject to the coordinate space of
 the receiver.  The conversion takes orientation, mirroring, layer bounds and videoGravity into consideration.
 If the provided metadata object originates from an input source other than the preview layer's, nil will be returned.
 */
- (AVMetadataObject *)transformedMetadataObjectForMetadataObject:(AVMetadataObject *)metadataObject;

#if TARGET_OS_IPHONE

/*!
 @property orientationSupported
 @abstract
 Specifies whether or not the preview layer supports orientation.
 
 @discussion
 Changes in orientation are not supported on all hardware configurations.  An
 application should check the value of @"orientationSupported" before attempting to
 manipulate the orientation of the receiver.  This property is deprecated.  Use
 AVCaptureConnection's -isVideoOrientationSupported instead.
 */
@property (nonatomic, readonly, getter=isOrientationSupported) BOOL orientationSupported NS_DEPRECATED_IOS(4_0, 6_0, "Use AVCaptureConnection's isVideoOrientationSupported instead.");

/*!
 @property orientation
 @abstract
 Specifies the orientation of the preview layer.
 
 @discussion
 AVCaptureVideoOrientation and its constants are defined in AVCaptureSession.h.
 The value of @"orientationSupported" must be YES in order to set @"orientation".  An
 exception will be raised if this requirement is ignored.  This property is deprecated.
 Use AVCaptureConnection's -videoOrientation instead.
 */
@property (nonatomic) AVCaptureVideoOrientation orientation NS_DEPRECATED_IOS(4_0, 6_0, "Use AVCaptureConnection's videoOrientation instead.");

/*!
 @property mirroringSupported
 @abstract
 Specifies whether or not the preview layer supports mirroring.
 
 @discussion
 Mirroring is not supported on all hardware configurations.  An application should
 check the value of @"mirroringSupported" before attempting to manipulate mirroring
 on the receiver.  This property is deprecated.  Use AVCaptureConnection's
 -isVideoMirroringSupported instead.
 */
@property (nonatomic, readonly, getter=isMirroringSupported) BOOL mirroringSupported NS_DEPRECATED_IOS(4_0, 6_0, "Use AVCaptureConnection's isVideoMirroringSupported instead.");

/*!
 @property automaticallyAdjustsMirroring
 @abstract
 Specifies whether or not the value of @"mirrored" can change based on configuration
 of the session.
	
 @discussion
 For some session configurations, preview will be mirrored by default.  When the value
 of this property is YES, the value of @"mirrored" may change depending on the configuration
 of the session, for example after switching to a different AVCaptureDeviceInput.
 The default value is YES.  This property is deprecated.  Use AVCaptureConnection's
 -automaticallyAdjustsVideoMirroring instead.
 */
@property (nonatomic) BOOL automaticallyAdjustsMirroring NS_DEPRECATED_IOS(4_0, 6_0, "Use AVCaptureConnection's automaticallyAdjustsVideoMirroring instead.");

/*!
 @property mirrored
 @abstract
 Specifies whether or not the preview is flipped over a vertical axis.
	
 @discussion
 For most applications, it is unnecessary to manipulate preview mirroring manually if
 @"automaticallyAdjustsMirroring" is set to YES.
 The value of @"automaticallyAdjustsMirroring" must be NO in order to set @"mirrored".
 The value of @"mirroringSupported" must be YES in order to set @"mirrored".  An
 exception will be raised if the value of @"mirrored" is mutated without respecting
 these requirements.  This property is deprecated.  Use AVCaptureConnection's
 -videoMirrored instead.
 */
@property (nonatomic, getter=isMirrored) BOOL mirrored NS_DEPRECATED_IOS(4_0, 6_0, "Use AVCaptureConnection's videoMirrored instead.");

#endif // TARGET_OS_IPHONE

@end
