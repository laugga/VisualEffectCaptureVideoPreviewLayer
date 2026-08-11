/*

 LAUCaptureVideoPreviewLayer.m
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

#import "LAUCaptureVideoPreviewLayer.h"
#import "LAUCaptureVideoPreviewLayerLogging.h"
#import "LAUCaptureVideoPreviewLayerInternal.h"
#import "LAUCaptureVideoPreviewLayerStructures.h"
#import "LAUCaptureVideoPreviewLayerShaders.h"
#import "LAUCaptureVideoPreviewLayerUtilities.h"
#import "LAUCaptureVideoPreviewLayerGaussianFilterKernel.h"

#import <AVFoundation/AVCaptureOutput.h>
#import <CoreVideo/CVMetalTextureCache.h>
#import <Metal/Metal.h>

@interface LAUCaptureVideoPreviewLayer () <LAUCaptureVideoPreviewLayerInternalDelegate>
{
    // Metal command queue and shader library
    id<MTLCommandQueue> _commandQueue;
    id<MTLLibrary> _library;

    // Layer used to display a snapshot image of the current framebuffer
    CALayer * _onscreenSnapshotImageSublayer;

    // CoreAnimation layer for previewing the visual output of an AVCaptureSession
    // Used for normal rendering. More efficient (CPU and GPU) than our own...
    AVCaptureVideoPreviewLayer * _videoPreviewSublayer;

    // Display link (works only on IOS 3.1 or greater)
    CADisplayLink * _displayLink;

    // Metal texture cache (core video)
    CVMetalTextureCacheRef _metalTextureCache;

    // Last Pixel buffer set
    // Waiting to be rendered or last one rendered
    CVMetalTextureRef _pixelBufferTexture;

    // Render pipeline states, the Metal equivalent of the linked glsl programs
    id<MTLRenderPipelineState> _defaultPipelineState; // On-screen
    id<MTLRenderPipelineState> _blurFilterPipelineState; // Off-screen

    // Texture sampling, shared by every render pipeline
    id<MTLSamplerState> _samplerState;

    // Shader arguments
    FilterUniforms_t _filterUniforms;

    // Offscreen render targets
    LAUTextureInstance * _pixelBufferTextureInstance;
    NSArray<LAUTextureInstance *> * _offscreenTextureInstances; // 2, ping-pong

    // Pixel buffer dimensions, before any downsampling is applied
    float _pixelBufferTextureNativeWidth;
    float _pixelBufferTextureNativeHeight;

    // Onscreen drawable
    NSInteger _onscreenDrawableWidth;
    NSInteger _onscreenDrawableHeight;
    LAUTextureInstance * _onscreenTextureInstance;

    // Texture instance drawn by the last onscreen pass, used for the snapshot
    LAUTextureInstance * _onscreenSourceTextureInstance;

    // Texture used to read back the onscreen contents (renderInContext:)
    id<MTLTexture> _onscreenSnapshotTexture;

    // Filter (Kernel)
    size_t _filterKernelCount; // Number of filter kernels created
    size_t _filterKernelIndex; // Currently loaded filter kernel
    FilterKernel_t * _filterKernelArray; // Kernels used for the interpolation between [0,1]

    // Filter (Parameters)
    float _filterSplitPassDirectionVector[2]; // Separable filter, apply 2x each in a specific direction (x or y)
    unsigned int _filterMultiplePassCount; // Number of times filter should be applied before onscreen rendering
    float _filterDownsamplingFactor; // Downsample offscreen textures by a factor (ie. 2 = resize dimensions by 1/2)

    // Filter (Intensity)
    float _filterIntensity; // [0,1], 0 means no filter is applied
    BOOL _filterIntensityNeedsUpdate; // YES if filter intensity changed between draw calls
    dispatch_source_t _filterIntensityTransitionTimer; // Use for animated transition between different indices
    float _filterIntensityTransitionTarget;

    // Filter (Bounds)
    float _filterBounds[4];
    BOOL _filterBoundsNeedsUpdate;
}

// Property used to control access to display link
@property (nonatomic, readonly) CADisplayLink * displayLink;

@end

@implementation LAUCaptureVideoPreviewLayer

#define FilterBoundsEnabled 0
#define FilterBilinearTextureSamplingEnabled 1

#pragma mark -
#pragma mark Initialization

- (instancetype)initWithSession:(AVCaptureSession *)session
{
    self = [super init];
    if (self)
    {
        // Assign the AVCaptureSession, which is managed by a LAUCaptureVideoPreviewLayerInternal instance
        self.session = session;

        // We use the native scale of the screen as our content scale factor.
        // This allows us to render to the exact pixel resolution of the screen which avoids additional scaling and GPU rendering work.
        // For example the iPhone 6 Plus appears to UIKit as a 736 x 414 pt screen with a 3x scale factor (2208 x 1242 virtual pixels).
        // But the native pixel dimensions are actually 1920 x 1080.
        // Since we are streaming 1080p buffers from the camera we can render to the iPhone 6 Plus screen at 1:1 with no additional scaling if we set everything up correctly.
        // Using the native scale of the screen also allows us to render at full quality when using the display zoom feature on iPhone 6/6 Plus.
        self.contentsScale = [UIScreen mainScreen].nativeScale;

        // Setup the CAMetalLayer for onscreen rendering
        self.opaque = YES;
        self.pixelFormat = MTLPixelFormatBGRA8Unorm;
        self.framebufferOnly = YES;

        // The Metal device replaces the EAGLContext
        self.device = MTLCreateSystemDefaultDevice();

        if (!self.device)
        {
            Log(@"LAUCaptureVideoPreviewLayer: Could not create a valid MTLDevice");
            return nil;
        }

        _commandQueue = [self.device newCommandQueue];
        _library = loadLibrary(self.device);

        if (!_commandQueue || !_library)
        {
            Log(@"LAUCaptureVideoPreviewLayer: Could not create a valid MTLCommandQueue or MTLLibrary");
            return nil;
        }

        // Texture instances used by the offscreen and onscreen passes
        _pixelBufferTextureInstance = [LAUTextureInstance new];
        _offscreenTextureInstances = @[[LAUTextureInstance new], [LAUTextureInstance new]];
        _onscreenTextureInstance = [LAUTextureInstance new];

        // Filter bounds default to the whole texture
        _filterUniforms.filterBounds = simd_make_float4(0.0f, 0.0f, 1.0f, 1.0f);

        // Preemptively load filter in memory
        [self loadFilter];
    }
    return self;
}

- (void)dealloc
{
    if (_pixelBufferTexture)
    {
        CFRelease(_pixelBufferTexture);
        _pixelBufferTexture = NULL;
    }

    if (_metalTextureCache)
    {
        CFRelease(_metalTextureCache);
        _metalTextureCache = NULL;
    }

    if (_filterKernelArray)
    {
        for (size_t i = 0; i < _filterKernelCount; ++i)
        {
            releaseFilterKernel(&_filterKernelArray[i]);
        }

        free(_filterKernelArray);
        _filterKernelArray = NULL;
    }
}

- (void)layoutSublayers
{
    PrettyLog;

    [super layoutSublayers];

    // Keep the drawable in sync with the layer bounds
    [self updateDrawableSize];

    if (!_defaultPipelineState)
    {
        // Load the render pipeline states and the sampler state
        [self loadBlurFilterPipelineState];
        [self loadDefaultPipelineState];
        [self loadSamplerState];

        // Metal pre-warm
        if (!_internal.sampleBuffer)
        {
            [self drawColor:self.backgroundColor];
        }

        // Set filter intensity from blur value
        [self setFilterIntensity:_blur];
    #if FilterBoundsEnabled
        [self setFilterBoundsRect:CGRectMake(0, 0, 1, 0.5)];
    #endif
    }
}

- (void)loadDefaultPipelineState
{
    if (_defaultPipelineState)
    {
        return;
    }

    // Load default render pipeline state
    _defaultPipelineState = loadRenderPipelineState(self.device, _library, VertexShaderNameDefault, FragmentShaderNameDefault, self.pixelFormat, @"Default");
}

- (void)loadBlurFilterPipelineState
{
    if (_blurFilterPipelineState)
    {
        return;
    }

    // Load blur filter render pipeline state
#if FilterBilinearTextureSamplingEnabled
#if FilterBoundsEnabled
    NSString * fragmentShaderName = FragmentShaderNameBlurFilterBtsBounds;
#else
    NSString * fragmentShaderName = FragmentShaderNameBlurFilterBts;
#endif
#else
    NSString * fragmentShaderName = FragmentShaderNameBlurFilterDts;
#endif

    _blurFilterPipelineState = loadRenderPipelineState(self.device, _library, VertexShaderNameDefault, fragmentShaderName, self.pixelFormat, @"Blur Filter");
}

- (void)loadSamplerState
{
    if (_samplerState)
    {
        return;
    }

    // Linear filtering and clamp to edge, for every texture sampled by the shaders
    _samplerState = loadSamplerState(self.device);
}

- (void)unloadPipelineStates
{
    // TODO
}

+ (Class)layerClass
{
    return [LAUCaptureVideoPreviewLayer class];
}

- (void)renderInContext:(CGContextRef)context
{
    [self renderInContext:context andRedrawPixelBuffer:YES];
}

static void releasePixelsData(void * info, const void * data, size_t size)
{
    free((void *)data);
}

- (void)renderInContext:(CGContextRef)context andRedrawPixelBuffer:(BOOL)redrawPixelBuffer
{
    // Redraw pixelBuffer, otherwise the last drawn texture instance is used
    if (redrawPixelBuffer) {
        [self drawPixelBuffer:nil];
    }

    // Nothing was ever drawn, there is nothing to read back
    if (!_onscreenSourceTextureInstance)
    {
        Log(@"LAUCaptureVideoPreviewLayer: No texture instance was drawn yet. I am just going to bailout.");
        return;
    }

    // The contents of a CAMetalDrawable can not be read back after being presented,
    // so the onscreen pass is drawn once more into a texture we own
    id<MTLTexture> snapshotTexture = [self onscreenSnapshotTexture];

    if (!snapshotTexture)
    {
        return;
    }

    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    [self drawOnscreenOffscreenTextureInstance:_onscreenSourceTextureInstance intoTexture:snapshotTexture commandBuffer:commandBuffer];
    [commandBuffer commit];
    [commandBuffer waitUntilCompleted];

    // Assuming MTLPixelFormatBGRA8Unorm format is used
    NSUInteger pixelsDataBytesPerRow = _onscreenDrawableWidth * 4;
    NSUInteger pixelsDataSize = pixelsDataBytesPerRow * _onscreenDrawableHeight;
    uint8_t * pixelsData = (uint8_t *)calloc(pixelsDataSize, sizeof(uint8_t));

    // Read pixel data from the snapshot texture
    [snapshotTexture getBytes:pixelsData
                  bytesPerRow:pixelsDataBytesPerRow
                   fromRegion:MTLRegionMake2D(0, 0, _onscreenDrawableWidth, _onscreenDrawableHeight)
                  mipmapLevel:0];

    // Create a CGImage instance with the pixels data
    // Metal gives us BGRA, which is 32 bits little-endian with the alpha component first
    CGDataProviderRef dataProvider = CGDataProviderCreateWithData(NULL, pixelsData, pixelsDataSize, releasePixelsData);
    CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
    CGImageRef image = CGImageCreate(_onscreenDrawableWidth,
                                     _onscreenDrawableHeight,
                                     8,
                                     32,
                                     pixelsDataBytesPerRow,
                                     colorspace,
                                     kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst,
                                     dataProvider,
                                     NULL,
                                     true,
                                     kCGRenderingIntentDefault);

    CGFloat width = _onscreenDrawableWidth / self.contentsScale;
    CGFloat height = _onscreenDrawableHeight / self.contentsScale;

    // Unlike glReadPixels, which returned the rows bottom-up, the first row read from a
    // MTLTexture is the top one. Flip the context so the image is not drawn upside down
    // (UIKit coordinate system is the inverse of the Quartz/Metal coordinate system).
    CGContextSaveGState(context);
    CGContextSetBlendMode(context, kCGBlendModeCopy);
    CGContextTranslateCTM(context, 0.0, height);
    CGContextScaleCTM(context, 1.0, -1.0);
    CGContextDrawImage(context, CGRectMake(0.0, 0.0, width, height), image);
    CGContextRestoreGState(context);

    CFRelease(dataProvider);
    CFRelease(colorspace);
    CGImageRelease(image);
}

#pragma mark -
#pragma mark CADisplayLink

- (CADisplayLink *)displayLink
{
    if (!_displayLink)
    {
        // Create and setup displayLink
        _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(drawPixelBuffer:)];
        [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
        _displayLink.paused = YES;
    }

    return _displayLink;
}

- (void)setDisplayLinkPaused:(BOOL)displayLinkPaused
{
    // The display link is only ours to control while the AVCaptureVideoPreviewLayer
    // sublayer is not the one on screen. When there is no such sublayer at all, which
    // is the case for a session that could not be previewed by AVFoundation, we are
    // the only thing that can draw
    if (!_videoPreviewSublayer || _videoPreviewSublayer.hidden)
    {
        self.displayLink.paused = displayLinkPaused;
    }
}

#pragma mark -
#pragma mark Blur property

- (void)setBlur:(CGFloat)blur
{
    [self setBlur:blur animated:NO];
}

- (void)setBlur:(CGFloat)blur animated:(BOOL)animated
{
    _blur = MIN(1.0f, MAX(0.0f, blur));
    [self setFilterIntensity:_blur animated:animated];
}

#pragma mark -
#pragma mark AVCaptureSession

- (AVCaptureSession *)session
{
    return self.internal.session;
}

- (void)setSession:(AVCaptureSession *)session
{
    self.internal.session = session;
}

#pragma mark -
#pragma mark AVCaptureVideoPreviewLayer

- (void)addAVCaptureVideoPreviewSublayer
{
    PrettyLog;

    if (self.internal.session)
    {
        if (!_videoPreviewSublayer)
        {
            // Create the session video preview layer from AVFoundation
            _videoPreviewSublayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.internal.session];

            _videoPreviewSublayer.backgroundColor = self.backgroundColor;
            _videoPreviewSublayer.videoGravity = AVLayerVideoGravityResizeAspectFill;  // TODO self.videoGravity
            _videoPreviewSublayer.bounds = self.bounds;
            _videoPreviewSublayer.anchorPoint = CGPointMake(0,0);
            _videoPreviewSublayer.hidden = YES;

            [self addSublayer:_videoPreviewSublayer];
        }

        [CATransaction begin];
        [CATransaction setValue: (id) kCFBooleanTrue forKey: kCATransactionDisableActions];
        _videoPreviewSublayer.hidden = NO;
        [CATransaction commit];

        self.displayLink.paused = YES;
        [self flushPixelBufferCache];
    }
}

- (void)removeAVCaptureVideoPreviewSublayer
{
    PrettyLog;

    if (_videoPreviewSublayer)
    {
        [self drawPixelBuffer:nil];
        self.displayLink.paused = NO;

        [CATransaction begin];
        [CATransaction setValue: (id) kCFBooleanTrue forKey: kCATransactionDisableActions];
        _videoPreviewSublayer.hidden = YES;
        [CATransaction commit];
    }
}

#pragma mark -
#pragma mark LAUCaptureVideoPreviewLayerInternal

- (LAUCaptureVideoPreviewLayerInternal *)internal
{
    if (!_internal)
    {
        _internal = [LAUCaptureVideoPreviewLayerInternal new];
        _internal.delegate = self;
    }

    return _internal;
}

- (void)captureVideoPreviewLayerInternal:(LAUCaptureVideoPreviewLayerInternal *)internal sessionDidStopRunning:(AVCaptureSession *)session
{
    [self setBlur:1.0 animated:YES];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self setDisplayLinkPaused:YES]; // TODO pause when blur-in animation finishes
    });
}

- (void)captureVideoPreviewLayerInternal:(LAUCaptureVideoPreviewLayerInternal *)internal sessionDidStartRunning:(AVCaptureSession *)session
{
    // Delay the fade out transition because first frames after session starts running are darker
    CFTimeInterval fadeOutDelay = 0.7f;

    // This will show the snapshot image layer to hide the dark frames
    [self addOnscreenSnapshotImageSublayer];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self setDisplayLinkPaused:NO]; // TODO investigate why first frames after session starts running are darker...
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(fadeOutDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self removeOnscreenSnapshotImageSublayer];
        [self setBlur:0.0 animated:YES];
    });
}

#pragma mark -
#pragma mark Texture Instance (CVPixelBufferRef)

- (CVPixelBufferRef)pixelBufferFromImageNamed:(NSString *)imageName
{
    CGImageRef image = [UIImage imageNamed:imageName].CGImage;

    if (!image) {
        Log(@"Failed to load image %@", imageName);
        return NULL;
    }

    size_t width = CGImageGetWidth(image);
    size_t height = CGImageGetHeight(image);

    CVPixelBufferRef pixelBuffer = NULL;
    NSDictionary * pixelBufferAttributes = @{ (NSString *)kCVPixelBufferCGImageCompatibilityKey: @YES,
                                              (NSString *)kCVPixelBufferCGBitmapContextCompatibilityKey: @YES,
                                              (NSString *)kCVPixelBufferMetalCompatibilityKey: @YES };

    CVReturn result = CVPixelBufferCreate(NULL, width, height, kCVPixelFormatType_32BGRA, (__bridge CFDictionaryRef)pixelBufferAttributes, &pixelBuffer);

    if (result != kCVReturnSuccess) {
        Log(@"Failed to create pixelBuffer from image %@", imageName);
        return NULL;
    }

    CIContext * coreImageContext = [CIContext contextWithCGContext:UIGraphicsGetCurrentContext() options:nil];
    [coreImageContext render:[CIImage imageWithCGImage:image] toCVPixelBuffer:pixelBuffer];

    return pixelBuffer;
}

- (CVMetalTextureRef)metalTextureFromPixelBuffer:(CVPixelBufferRef)pixelBuffer
{
    // Create a new CVMetalTexture cache
    if (!_metalTextureCache)
    {
        NSDictionary * cacheAttributes = @{ (NSString *)kCVMetalTextureCacheMaximumTextureAgeKey: @(0.1) };

        CVReturn result = CVMetalTextureCacheCreate(kCFAllocatorDefault, (__bridge CFDictionaryRef _Nullable)(cacheAttributes), self.device, NULL, &_metalTextureCache);
        if (result != kCVReturnSuccess)
        {
            Log(@"LAUCaptureVideoPreviewLayer: Error at CVMetalTextureCacheCreate %d", result);
            return NULL;
        }
    }

    // Create a CVMetalTexture from a CVPixelBufferRef
    size_t textureWidth = CVPixelBufferGetWidth(pixelBuffer);
    size_t textureHeight = CVPixelBufferGetHeight(pixelBuffer);
    CVMetalTextureRef metalTexture = NULL;
    CVReturn result = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                                _metalTextureCache,
                                                                pixelBuffer,
                                                                NULL,
                                                                MTLPixelFormatBGRA8Unorm,
                                                                textureWidth,
                                                                textureHeight,
                                                                0,
                                                                &metalTexture);

    if (result != kCVReturnSuccess)
    {
        Log(@"CVMetalTextureCacheCreateTextureFromImage failed (error: %d)", result);
        return NULL;
    }

    return metalTexture;
}

- (void)flushPixelBufferCache
{
    // Release old pixelBuffer texture if it exists
    if (_pixelBufferTexture)
    {
        CFRelease(_pixelBufferTexture);
        _pixelBufferTexture = NULL;
    }

    if (_metalTextureCache)
    {
        CVMetalTextureCacheFlush(_metalTextureCache, 0);
    }
}

#pragma mark -
#pragma mark Offscreen rendering

- (id<MTLTexture>)createRenderTargetForOffscreenTextureInstance:(LAUTextureInstance *)offscreenTextureInstance
{
    // Create the texture to render, it doubles as the render target of the pass.
    // In Metal there is no framebuffer object to attach it to, the render pass
    // descriptor points at the texture directly.
    offscreenTextureInstance.texture = loadRenderTargetTexture(self.device,
                                                               (NSUInteger)roundf(offscreenTextureInstance.textureWidth),
                                                               (NSUInteger)roundf(offscreenTextureInstance.textureHeight),
                                                               self.pixelFormat,
                                                               MTLStorageModePrivate);

    offscreenTextureInstance.renderPassDescriptor = loadRenderPassDescriptor(offscreenTextureInstance.texture);

    return offscreenTextureInstance.texture;
}

- (void)loadOffscreenTextureInstance:(LAUTextureInstance *)offscreenTextureInstance
{
    // Create a new offscreen render target
    [self createRenderTargetForOffscreenTextureInstance:offscreenTextureInstance];

    // Use triangle strip
    offscreenTextureInstance.primitiveType = MTLPrimitiveTypeTriangleStrip;

    // Vertex data
    //
    // The texture coordinates are vertically flipped when compared with the OpenGL ES
    // implementation. Metal renders the first row of a texture at the top of the
    // viewport, while OpenGL rendered it at the bottom, so flipping the coordinates
    // here keeps every offscreen pass an exact copy of its source, whatever the
    // number of passes applied.
    static const VertexData_t vertexData[] = {
        {
            {-1.0f, -1.0f}, // Position, bottom left
            {0.0f, 1.0f} // Texture Coordinate
        },
        {
            {1.0f, -1.0f}, // bottom right
            {1.0f, 1.0f}
        },
        {
            {-1.0f,  1.0f}, // top left
            {0.0f,  0.0f}
        },
        {
            {1.0f,  1.0f}, // top right
            {1.0f,  0.0f}
        }
    };

    offscreenTextureInstance.vertexCount = 4;
    offscreenTextureInstance.vertexBuffer = [self.device newBufferWithBytes:vertexData
                                                                     length:sizeof(vertexData)
                                                                    options:MTLResourceStorageModeShared];
}

- (void)scaleDownPixelBufferTextureInstanceDimensions
{
    // Default downsampling factor
    float textureDownsamplingFactor = _filterDownsamplingFactor;

    // Pixel buffer dimensions and ratio.
    // The native dimensions are used, and not the ones currently set on the texture
    // instance, so that a pixel buffer which is drawn more than once (when no new
    // sample buffer is available) is not downsampled again on every draw call.
    float pixelBufferWidth = _pixelBufferTextureNativeWidth;
    float pixelBufferHeight = _pixelBufferTextureNativeHeight;
    float pixelBufferRatio = pixelBufferWidth / pixelBufferHeight; // Usually the pixelBuffer w > h

    // Screen dimensions and ratio
    float onscreenWidth = ((float)_onscreenDrawableWidth);
    float onscreenHeight = ((float)_onscreenDrawableHeight);
    float onscreenRatio = onscreenHeight / onscreenWidth;

    if (onscreenRatio > pixelBufferRatio)
    {
        // Use height to calculate downsampling effective factor on pixelBuffer
        textureDownsamplingFactor = pixelBufferWidth / (onscreenHeight / _filterDownsamplingFactor);
    }
    else
    {
        // Use width to calculate downsampling effective factor on pixelBuffer
        textureDownsamplingFactor = pixelBufferHeight / (onscreenWidth / _filterDownsamplingFactor);
    }

    // Downsample input pixelBuffer by a specific factor.
    // The dimensions are rounded to whole pixels: they end up being both the size of
    // the offscreen texture and the size of the viewport drawn into it, and a viewport
    // narrower than its render target would leave the last row or column of the
    // texture unrasterized.
    float scaledWidth = MAX(1.0f, roundf(pixelBufferWidth / textureDownsamplingFactor));
    float scaledHeight = MAX(1.0f, roundf(pixelBufferHeight / textureDownsamplingFactor));

    // Create a temporary offscreen texture instance wrapping the pixelBuffer
    _pixelBufferTextureInstance.textureWidth = scaledWidth;
    _pixelBufferTextureInstance.textureHeight = scaledHeight;
}

- (void)drawOffscreenTextureInstance:(LAUTextureInstance *)srcTextureInstance onOffscreenTextureInstance:(LAUTextureInstance *)destTextureInstance commandBuffer:(id<MTLCommandBuffer>)commandBuffer
{
    // Check dimensions of the source texture instance
    float width = srcTextureInstance.textureWidth;
    float height = srcTextureInstance.textureHeight;

    // Check if dimensions changed and load again if needed
    if (destTextureInstance.textureWidth != width || destTextureInstance.textureHeight != height)
    {
        destTextureInstance.textureWidth = width;
        destTextureInstance.textureHeight = height;

        // Load offscreen texture instance
        [self loadOffscreenTextureInstance:destTextureInstance];
    }

    if (!destTextureInstance.renderPassDescriptor || !destTextureInstance.texture)
    {
        Log(@"Invalid offscreen texture instance render target. I am just going to bailout.");
        return;
    }

    // Set the filter split-pass direction vector
    [self setFilterSplitPassDirectionVectorForTextureInstance:destTextureInstance];

    // Encode the pass, the destination texture is the render target
    id<MTLRenderCommandEncoder> renderCommandEncoder = [commandBuffer renderCommandEncoderWithDescriptor:destTextureInstance.renderPassDescriptor];
    renderCommandEncoder.label = @"Offscreen Blur Filter Pass";

    // Set the view port to the entire destination texture.
    // The texture dimensions are used, and not the instance ones, so that the viewport
    // always covers every pixel of the render target
    [renderCommandEncoder setViewport:(MTLViewport){0.0, 0.0, (double)destTextureInstance.texture.width, (double)destTextureInstance.texture.height, 0.0, 1.0}];

    // Use the blur filter render pipeline state
    [renderCommandEncoder setRenderPipelineState:_blurFilterPipelineState];

    // Bind the geometry and the filter arguments
    [renderCommandEncoder setVertexBuffer:destTextureInstance.vertexBuffer offset:0 atIndex:BufferIndexVertices];
    [renderCommandEncoder setFragmentBytes:&_filterUniforms length:sizeof(_filterUniforms) atIndex:BufferIndexFilterUniforms];

    // Bind the src texture
    [renderCommandEncoder setFragmentTexture:srcTextureInstance.texture atIndex:TextureIndexSource];
    [renderCommandEncoder setFragmentSamplerState:_samplerState atIndex:SamplerIndexSource];

    // Draw the instance
    [renderCommandEncoder drawPrimitives:destTextureInstance.primitiveType vertexStart:0 vertexCount:destTextureInstance.vertexCount];

    [renderCommandEncoder endEncoding];
}

#pragma mark -
#pragma mark Onscreen rendering

- (void)updateDrawableSize
{
    CGSize boundsSize = self.bounds.size;

    NSInteger drawableWidth = (NSInteger)roundf(boundsSize.width * self.contentsScale);
    NSInteger drawableHeight = (NSInteger)roundf(boundsSize.height * self.contentsScale);

    if (drawableWidth <= 0 || drawableHeight <= 0)
    {
        return;
    }

    if (drawableWidth == _onscreenDrawableWidth && drawableHeight == _onscreenDrawableHeight)
    {
        return;
    }

    _onscreenDrawableWidth = drawableWidth;
    _onscreenDrawableHeight = drawableHeight;

    self.drawableSize = CGSizeMake(drawableWidth, drawableHeight);

    // The onscreen quad texture coordinates are aspect-fit against the drawable
    // dimensions, invalidate it so it is loaded again on the next draw call
    _onscreenTextureInstance.textureWidth = 0;
    _onscreenTextureInstance.textureHeight = 0;

    // The snapshot texture has to match the new drawable dimensions
    _onscreenSnapshotTexture = nil;
}

- (id<MTLTexture>)onscreenSnapshotTexture
{
    if (!_onscreenSnapshotTexture && _onscreenDrawableWidth > 0 && _onscreenDrawableHeight > 0)
    {
        // Shared storage so the contents can be read back with getBytes:
        _onscreenSnapshotTexture = loadRenderTargetTexture(self.device, _onscreenDrawableWidth, _onscreenDrawableHeight, self.pixelFormat, MTLStorageModeShared);
    }

    return _onscreenSnapshotTexture;
}

- (CGPoint)onscreenTextureCoordinatesOffsetsForTextureInstance:(LAUTextureInstance *)textureInstance
{
    // We assume the pixelBuffer is landscape, rotated 90 degrees anti-clockwise
    // So:
    // 1. We switch width and height
    // 2. Rotate 90 degrees clockwise by mapping the texture coordinates
    // The pixel bufferr (and texture) remain unchanged.
    // We only flip the viewHeight/viewWidth and map the texture to the appropriate vertices so it is rotated.
    _onscreenTextureInstance.textureWidth = textureInstance.textureWidth;
    _onscreenTextureInstance.textureHeight = textureInstance.textureHeight;

    // Ratio of view versus. texture
    float viewRatio = ((float)_onscreenDrawableHeight) / ((float)_onscreenDrawableWidth);
    float textureRatio = _onscreenTextureInstance.textureWidth / _onscreenTextureInstance.textureHeight;

    // Change S (T=1) if texture ratio <= view ratio
    // Change T (S=1) if texture ration > view ratio
    BOOL changeT = textureRatio > viewRatio; // changeT = !changeS

    // Calculate the texture scale factor
    float textureScale = 1.0;

    // Change T, means we need to check view height vs. texture height
    // T is going to map [0,1]
    if (changeT) {
        textureScale = ((float)_onscreenDrawableWidth) / _onscreenTextureInstance.textureHeight;
    }
    // Change S, means we need to check view width vs. texture width
    // S is going to map [0,1]
    else {
        textureScale = ((float)_onscreenDrawableHeight) / _onscreenTextureInstance.textureWidth;
    }

    // Calculate texture scaled dimensions
    float _scaledTextureHeight = _onscreenTextureInstance.textureHeight * textureScale;
    float _scaledTextureWidth = _onscreenTextureInstance.textureWidth * textureScale;

    // Calculate texture coordinates S and D deltas
    float _deltaTextureCoordinateS = (_scaledTextureWidth-((float)_onscreenDrawableHeight)) / _scaledTextureWidth / 2.0;
    float _deltaTextureCoordinateT = (_scaledTextureHeight-((float)_onscreenDrawableWidth)) / _scaledTextureHeight / 2.0;

    // Update the texture coordinates
    return CGPointMake(_deltaTextureCoordinateS, _deltaTextureCoordinateT);
}

- (void)loadOnscreenTextureInstanceFor:(LAUTextureInstance *)textureInstance
{
    // Use triangle strip
    _onscreenTextureInstance.primitiveType = MTLPrimitiveTypeTriangleStrip;

    // Calculate the texture coordinates offsets for the input textureInstance
    CGPoint textureCoordinatesOffsets = [self onscreenTextureCoordinatesOffsetsForTextureInstance:textureInstance];

    // Vertex data
    VertexData_t vertexData[] = {
        {
            {-1.0f, -1.0f}, // Position, bottom left
            {1.0f - textureCoordinatesOffsets.x, 1.0f - textureCoordinatesOffsets.y} // Texture Coordinate
        },
        {
            {1.0f, -1.0f}, // bottom right
            {1.0f - textureCoordinatesOffsets.x, 0.0f + textureCoordinatesOffsets.y}
        },
        {
            {-1.0f,  1.0f}, // top left
            {0.0f + textureCoordinatesOffsets.x,  1.0f - textureCoordinatesOffsets.y}
        },
        {
            {1.0f,  1.0f}, // top right
            {0.0f + textureCoordinatesOffsets.x,  0.0f + textureCoordinatesOffsets.y}
        }
    };

    _onscreenTextureInstance.vertexCount = 4;
    _onscreenTextureInstance.vertexBuffer = [self.device newBufferWithBytes:vertexData
                                                                     length:sizeof(vertexData)
                                                                    options:MTLResourceStorageModeShared];
}

- (void)drawOnscreenOffscreenTextureInstance:(LAUTextureInstance *)offscreenTextureInstance intoTexture:(id<MTLTexture>)texture commandBuffer:(id<MTLCommandBuffer>)commandBuffer
{
    if (!texture)
    {
        Log(@"Invalid onscreen render target. I am just going to bailout.");
        return;
    }

    // Check dimensions of the pixelBuffer
    float width = offscreenTextureInstance.textureWidth;
    float height = offscreenTextureInstance.textureHeight;

    // Check if dimensions changed and load again if needed
    if (_onscreenTextureInstance.textureWidth != width || _onscreenTextureInstance.textureHeight != height)
    {
        // Load texture instance
        [self loadOnscreenTextureInstanceFor:offscreenTextureInstance];
    }

    // Encode the pass, the drawable (or the snapshot texture) is the render target
    id<MTLRenderCommandEncoder> renderCommandEncoder = [commandBuffer renderCommandEncoderWithDescriptor:loadRenderPassDescriptor(texture)];
    renderCommandEncoder.label = @"Onscreen Pass";

    // Set the view port to the entire view
    [renderCommandEncoder setViewport:(MTLViewport){0.0, 0.0, (double)_onscreenDrawableWidth, (double)_onscreenDrawableHeight, 0.0, 1.0}];

    // Filtering is disabled for the final onscreen rendering
    [renderCommandEncoder setRenderPipelineState:_defaultPipelineState];

    // Bind the geometry
    [renderCommandEncoder setVertexBuffer:_onscreenTextureInstance.vertexBuffer offset:0 atIndex:BufferIndexVertices];

    // Bind the texture
    [renderCommandEncoder setFragmentTexture:offscreenTextureInstance.texture atIndex:TextureIndexSource];
    [renderCommandEncoder setFragmentSamplerState:_samplerState atIndex:SamplerIndexSource];

    // Draw the instance
    [renderCommandEncoder drawPrimitives:_onscreenTextureInstance.primitiveType vertexStart:0 vertexCount:_onscreenTextureInstance.vertexCount];

    [renderCommandEncoder endEncoding];
}

#pragma mark -
#pragma mark Onscreen framebuffer snapshot

- (UIImage *)imageFromOnscreenFramebuffer
{
    CGRect bounds = self.bounds;

    NSAssert(CGRectGetWidth(bounds) > 0, @"Layer %@ width is zero", self);
    NSAssert(CGRectGetHeight(bounds) > 0, @"Layer %@ height is zero", self);

    UIGraphicsBeginImageContextWithOptions(bounds.size, YES, 0);

    CGContextRef context = UIGraphicsGetCurrentContext();

    NSAssert(context != NULL, @"Invalid context for layer %@", self);

    CGContextSaveGState(context);

    [self renderInContext:context andRedrawPixelBuffer:NO];

    CGContextRestoreGState(context);

    UIImage * imageFromOnscreenFramebuffer = UIGraphicsGetImageFromCurrentImageContext();

    UIGraphicsEndImageContext();

    return imageFromOnscreenFramebuffer;
}

- (void)addOnscreenSnapshotImageSublayer
{
    if (_pixelBufferTexture != nil)
    {
        _onscreenSnapshotImageSublayer = [CALayer new];
        _onscreenSnapshotImageSublayer.bounds = self.bounds;
        _onscreenSnapshotImageSublayer.contentsScale = 2;
        _onscreenSnapshotImageSublayer.anchorPoint = CGPointMake(0, 0);
        _onscreenSnapshotImageSublayer.backgroundColor = self.backgroundColor;

        _onscreenSnapshotImageSublayer.contents = (__bridge id)[self imageFromOnscreenFramebuffer].CGImage;
        _onscreenSnapshotImageSublayer.opacity = 1.0;

        [self addSublayer:_onscreenSnapshotImageSublayer];
    }
}

- (void)removeOnscreenSnapshotImageSublayer
{
    if (_onscreenSnapshotImageSublayer)
    {
        [CATransaction begin];
        [CATransaction setCompletionBlock:^{
            [_onscreenSnapshotImageSublayer removeFromSuperlayer];
            _onscreenSnapshotImageSublayer = nil;
        }];

        [CATransaction setAnimationDuration:0.25f];
        [CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn]];

        _onscreenSnapshotImageSublayer.opacity = 0.0f;

        [CATransaction commit];
    }
}

#pragma mark -
#pragma mark Drawing

- (void)getCGColor:(CGColorRef)color componentsRed:(CGFloat *)red green:(CGFloat *)green blue:(CGFloat *)blue alpha:(CGFloat *)alpha
{
    *red = *green = *blue = 0.0;
    *alpha = 1.0;

    if (CGColorGetNumberOfComponents(color) == 4)
    {
        const CGFloat * colorComponents = CGColorGetComponents(color);
        *red = colorComponents[0];
        *green = colorComponents[1];
        *blue = colorComponents[2];
        *alpha = colorComponents[3];
    }
}

- (void)drawColor:(CGColorRef)color
{
    if (!_commandQueue)
    {
        Log(@"LAUCaptureVideoPreviewLayer: Metal command queue not initialized.");
        return;
    }

    id<CAMetalDrawable> drawable = [self nextDrawable];

    if (!drawable)
    {
        Log(@"LAUCaptureVideoPreviewLayer: No drawable available.");
        return;
    }

    // Use clear color with the argument color
    CGFloat red, green, blue, alpha;
    [self getCGColor:color componentsRed:&red green:&green blue:&blue alpha:&alpha];

    MTLRenderPassDescriptor * renderPassDescriptor = loadRenderPassDescriptor(drawable.texture);
    renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(red, green, blue, alpha);

    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    id<MTLRenderCommandEncoder> renderCommandEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    renderCommandEncoder.label = @"Clear Pass";
    [renderCommandEncoder endEncoding];

    [commandBuffer presentDrawable:drawable];
    [commandBuffer commit];
}

- (void)drawPixelBuffer:(CADisplayLink *)aDisplayLink
{
    PrettyLog;

    CMSampleBufferRef sampleBuffer = self.internal.sampleBuffer;

    if (sampleBuffer)
    {
        Log(@"*** LAUCaptureVideoPreviewLayer: sampleBuffer is OK (frame duration %fs)", aDisplayLink.duration);

        // New pixelBuffer available to be rendered ?
        CVPixelBufferRef pixelBuffer = (CVPixelBufferRef)CFRetain(CMSampleBufferGetImageBuffer(sampleBuffer));

        if (!pixelBuffer)
        {
            Log(@"*** LAUCaptureVideoPreviewLayer: pixelBuffer is nil");
            return;
        }

        // Release old pixelBuffer texture if it exists
        if (_pixelBufferTexture)
        {
            CFRelease(_pixelBufferTexture);
            _pixelBufferTexture = NULL;
        }

        // Check dimensions of the pixelBuffer
        float width = (float)CVPixelBufferGetWidth(pixelBuffer);
        float height = (float)CVPixelBufferGetHeight(pixelBuffer);

        // Get the Metal texture
        _pixelBufferTexture = [self metalTextureFromPixelBuffer:pixelBuffer];

        CFRelease(pixelBuffer);

        if (!_pixelBufferTexture)
        {
            return;
        }

        // Create a temporary offscreen texture instance wrapping the pixelBuffer
        _pixelBufferTextureNativeWidth = width;
        _pixelBufferTextureNativeHeight = height;
        _pixelBufferTextureInstance.textureWidth = width;
        _pixelBufferTextureInstance.textureHeight = height;
        _pixelBufferTextureInstance.texture = CVMetalTextureGetTexture(_pixelBufferTexture);
    }
    else if (_pixelBufferTexture)
    {
        Log(@"*** LAUCaptureVideoPreviewLayer: re-using last pixelBuffer texture (frame duration %fs)", aDisplayLink.duration);
    }
    else
    {
        Log(@"*** LAUCaptureVideoPreviewLayer: sampleBuffer and pixelBufferTexture are NULL. NOT going to render. (frame duration %fs)", aDisplayLink.duration);
        return;
    }

    if (!_defaultPipelineState || !_blurFilterPipelineState)
    {
        Log(@"*** LAUCaptureVideoPreviewLayer: render pipeline states are not loaded yet. NOT going to render.");
        return;
    }

    id<CAMetalDrawable> drawable = [self nextDrawable];

    if (!drawable)
    {
        Log(@"*** LAUCaptureVideoPreviewLayer: no drawable available. NOT going to render.");
        return;
    }

    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"LAUCaptureVideoPreviewLayer Frame";

    // Texture instance used by the final onscreen pass
    LAUTextureInstance * onscreenSourceTextureInstance = _pixelBufferTextureInstance;

    // Only filter if filter intensity is greater than 0
    if (_filterIntensity > 0)
    {
        // Update any filter argument that changed since last frame
        [self updateBlurFilterUniforms];

        // Downsample pixel buffer texture dimensions
        [self scaleDownPixelBufferTextureInstanceDimensions];

        // First Draw the pixel buffer in an offscreen texture instance (this is a special step)
        [self drawOffscreenTextureInstance:_pixelBufferTextureInstance onOffscreenTextureInstance:_offscreenTextureInstances[0] commandBuffer:commandBuffer];

        // Draw the offscreen texture instances and keep applying the filter (ping, pong, ping, pong)
        // Because we did already drew once, the number of draw calls left = 2 * multiple-pass-count - 1
        for (int p=1; p<(2*_filterMultiplePassCount); ++p)
        {
            // Draw split-pass (offscreen)
            [self drawOffscreenTextureInstance:_offscreenTextureInstances[(p+1)%2] onOffscreenTextureInstance:_offscreenTextureInstances[p%2] commandBuffer:commandBuffer];
        }

        onscreenSourceTextureInstance = _offscreenTextureInstances[1];
    }

    // Keep a reference for renderInContext:andRedrawPixelBuffer:
    _onscreenSourceTextureInstance = onscreenSourceTextureInstance;

    // Draw (onscreen)
    [self drawOnscreenOffscreenTextureInstance:onscreenSourceTextureInstance intoTexture:drawable.texture commandBuffer:commandBuffer];

    [commandBuffer presentDrawable:drawable];
    [commandBuffer commit];
}

- (void)updateBlurFilterUniforms
{
    if (_filterIntensityNeedsUpdate)
    {
        FilterKernel_t filterKernel = _filterKernelArray[_filterKernelIndex];

#if FilterBilinearTextureSamplingEnabled
        size_t samples = MIN((size_t)filterKernel.samples, (size_t)kFilterKernelMaxSamples);
        _filterUniforms.filterKernelSamples = (int)samples;
        memcpy(_filterUniforms.filterKernelOffsets, filterKernel.offsets, samples * sizeof(float));
        memcpy(_filterUniforms.filterKernelWeights, filterKernel.weights, samples * sizeof(float));
#else
        size_t size = MIN((size_t)filterKernel.size, (size_t)kFilterKernelMaxWeights);
        _filterUniforms.filterKernelRadius = (int)filterKernel.radius;
        _filterUniforms.filterKernelSize = (int)size;
        memcpy(_filterUniforms.filterKernelWeights, filterKernel.weights, size * sizeof(float));
#endif

        _filterIntensityNeedsUpdate = NO;
    }

#if FilterBoundsEnabled
    if (_filterBoundsNeedsUpdate)
    {
        _filterUniforms.filterBounds = simd_make_float4(_filterBounds[0], _filterBounds[1], _filterBounds[2], _filterBounds[3]);
        _filterBoundsNeedsUpdate = NO;
    }

#endif
}

#pragma mark -
#pragma mark Filtering (Intensity)

- (void)setFilterIntensity:(float)intensity
{
    float oldIntensity = _filterIntensity;

    // Bail out if the render pipeline state hasn't been loaded yet
    if (!_blurFilterPipelineState)
    {
        return;
    }

    // Load filter kernel (will do nothing if it's already loaded)
    [self loadFilter];

    // Clamp intensity between [0,1] range
    float newIntensity =  MAX(0, MIN(1, intensity));

    // Assign the intensity value
    _filterIntensity = newIntensity;

    // Map intensity to a integer kernel index
    size_t mappedIndex = (size_t)roundf(newIntensity * ((float)(_filterKernelCount-1)));

    // Assign the mapped index
    _filterKernelIndex =  MAX(0, MIN(_filterKernelCount-1, mappedIndex));

    _filterIntensityNeedsUpdate = YES;

    if (newIntensity > 0.0 && oldIntensity == 0.0)
    {
        [self removeAVCaptureVideoPreviewSublayer];
    }
    else if (newIntensity == 0.0)
    {
        [self addAVCaptureVideoPreviewSublayer];
    }
}

- (void)setFilterIntensity:(float)intensity animated:(BOOL)animated
{
    if (!animated)
    {
        [self setFilterIntensity:intensity];
        return;
    }

    // Assign target filter intensity
    _filterIntensityTransitionTarget = intensity;

    // Define timer step based on the number of kernels available
    float const filterIntensityTransitionStep = 1.0f / _filterKernelCount;

    _filterIntensityTransitionTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(_filterIntensityTransitionTimer, DISPATCH_TIME_NOW, (1.0f/60.0f) * NSEC_PER_SEC, 0.0 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(_filterIntensityTransitionTimer, ^{

        if (_filterIntensity != _filterIntensityTransitionTarget)
        {
            if (_filterIntensity < _filterIntensityTransitionTarget)
            {
                if ((_filterIntensity + filterIntensityTransitionStep) < _filterIntensityTransitionTarget)
                {
                    [self setFilterIntensity:(_filterIntensity + filterIntensityTransitionStep)];
                }
                else
                {
                    [self setFilterIntensity:_filterIntensityTransitionTarget];
                }
            }
            else if (_filterIntensity > _filterIntensityTransitionTarget)
            {
                if ((_filterIntensity - filterIntensityTransitionStep) > _filterIntensityTransitionTarget)
                {
                    [self setFilterIntensity:(_filterIntensity - filterIntensityTransitionStep)];
                }
                else
                {
                    [self setFilterIntensity:_filterIntensityTransitionTarget];
                }
            }
        }
        else
        {
            dispatch_source_cancel(_filterIntensityTransitionTimer);
        }

    });

    dispatch_resume(_filterIntensityTransitionTimer);
}

#pragma mark -
#pragma mark Filtering (Bounds)

#if FilterBoundsEnabled
- (void)setFilterBoundsRect:(CGRect)filterBoundsRect
{
    float xMin = filterBoundsRect.origin.x;
    float xMax = xMin + filterBoundsRect.size.width;
    float yMin = filterBoundsRect.origin.y;
    float yMax = yMin + filterBoundsRect.size.height;

    // Bounds within the texture that are filtered [xMin, yMin, xMax, yMax]
    // The textureCoordinates mapping rotate the texture 90 degrees clockwise
    // We need to flip x/y in textureFilterBounds to work with the rotation
    float filterBounds[4] = { yMin, 1.0 - xMax, yMax, 1.0 - xMin };
    memcpy(_filterBounds, filterBounds, 4*sizeof(float));
    _filterBoundsNeedsUpdate = YES;
}
#endif

#pragma mark -
#pragma mark Filtering (Kernel)

void createFilterKernel(int kernelIndex, FilterKernel_t * filterKernel)
{
#if FilterBilinearTextureSamplingEnabled
    unsigned int filterSamples = btsGaussianFilterSamplesForKernelIndex(kernelIndex);
    unsigned int filterRadius = btsGaussianFilterRadiusForKernelIndex(kernelIndex);
    float filterSigma = btsGaussianFilterSigmaForKernelIndex(kernelIndex);
    float filterStep = btsGaussianFilterStepForKernelIndex(kernelIndex);

    // Create 1D kernel
    float * filterWeights = calloc(filterSamples, sizeof(float)); // float
    float * filterOffsets = calloc(filterSamples, sizeof(float)); // float
    for (int sampleIndex=0; sampleIndex<filterSamples; ++sampleIndex)
    {
        filterWeights[sampleIndex] = btsGaussianFilterWeightForIndexes(kernelIndex, sampleIndex);
        filterOffsets[sampleIndex] = btsGaussianFilterOffsetForIndexes(kernelIndex, sampleIndex);
    }

    // Log kernel
    printf("kernel (step = %f, radius = %u, sigma = %f, samples = %u) [", filterStep, filterRadius, filterSigma, filterSamples);
    for (int i = 0; i<filterSamples; ++i)
    {
        printf(" (%f, %f) ", filterWeights[i], filterOffsets[i]);
    }
    printf("]\n");

    filterKernel->radius = filterRadius;
    filterKernel->samples = filterSamples;
    filterKernel->weights = filterWeights;
    filterKernel->offsets = filterOffsets;

#else

    unsigned int filterSize = dtsGaussianFilterSizeForKernelIndex(kernelIndex);
    unsigned int filterRadius = dtsGaussianFilterRadiusForKernelIndex(kernelIndex);
    float filterSigma = dtsGaussianFilterSigmaForKernelIndex(kernelIndex);
    float filterStep = dtsGaussianFilterStepForKernelIndex(kernelIndex);

    // Create 1D kernel
    float * filterWeights = calloc(filterSize, sizeof(float)); // float
    for (int weightIndex=0; weightIndex<filterSize; ++weightIndex)
    {
        filterWeights[weightIndex] = dtsGaussianFilterWeightForIndexes(kernelIndex, weightIndex);
    }

    // Log kernel
    printf("kernel (step = %f, size = %u, radius = %u, sigma = %f) [", filterStep, filterSize, filterRadius, filterSigma);
    for (int i = 0; i<filterSize; ++i)
    {
        printf(" %f ", filterWeights[i]);
    }
    printf("]\n");

    filterKernel->radius = filterRadius;
    filterKernel->size = filterSize;
    filterKernel->weights = filterWeights;
#endif
}

void releaseFilterKernel(FilterKernel_t * filterKernel)
{
    filterKernel->size = 0;
    filterKernel->radius = 0;
    free(filterKernel->weights);
    filterKernel->weights = NULL;

#if FilterBilinearTextureSamplingEnabled
    free(filterKernel->offsets);
    filterKernel->offsets = NULL;
#endif
}

- (void)loadFilter
{
    // Skip if it's already loaded
    if (_filterKernelCount)
    {
        return;
    }

    // Define how many filter kernels should be generated
    size_t filterKernelCount = gaussianFilterKernelCount();
    FilterKernel_t * filterKernelArray = (FilterKernel_t *)calloc(filterKernelCount, sizeof(FilterKernel_t));

    // Create all filter kernels
    for (int i=0; i<filterKernelCount; ++i)
    {
        createFilterKernel(i, &filterKernelArray[i]);
    }

    // Store in the TextureInstance
    _filterKernelCount = filterKernelCount;
    _filterKernelArray = filterKernelArray;

    // Filter parameters
    _filterDownsamplingFactor = 4.0f;
    _filterMultiplePassCount = 2;
}

- (void)setFilterSplitPassDirectionVectorForTextureInstance:(LAUTextureInstance *)textureInstance
{
    // Switch the previous vector
    if (_filterSplitPassDirectionVector[0] == 0)
    {
        _filterSplitPassDirectionVector[0] = 1;
        _filterSplitPassDirectionVector[1] = 0;
    }
    else
    {
        _filterSplitPassDirectionVector[0] = 0;
        _filterSplitPassDirectionVector[1] = 1;
    }

    // Set the filter step argument
    _filterUniforms.filterSplitPassDirectionVector = simd_make_float2(_filterSplitPassDirectionVector[0]/textureInstance.textureWidth,
                                                                     _filterSplitPassDirectionVector[1]/textureInstance.textureHeight);
}

@end
