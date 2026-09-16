/*

 LAUCaptureVideoPreviewLayerUtilities.m
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

#import "LAUCaptureVideoPreviewLayerUtilities.h"
#import "LAUCaptureVideoPreviewLayerLogging.h"
#import "LAUCaptureVideoPreviewLayerStructures.h"

#pragma mark -
#pragma mark Library loading

/*
 The shaders are compiled at build time into the default metallib of the target
 that links this library. Where that metallib ends up depends on how the library
 is consumed, so look for it in the bundle of this library first, then in the
 main bundle, and finally in a resource bundle named after the pod.
 */
id<MTLLibrary> loadLibrary(id<MTLDevice> device)
{
    NSMutableArray<NSBundle *> * bundles = [NSMutableArray array];

    // Swift Package Manager compiles the .metal sources into the default metallib of
    // the resource bundle it generates for this target
    if (SWIFTPM_MODULE_BUNDLE) {
        [bundles addObject:SWIFTPM_MODULE_BUNDLE];
    }

    NSBundle * libraryBundle = [NSBundle bundleForClass:[LAUTextureInstance class]];
    if (libraryBundle && ![bundles containsObject:libraryBundle]) {
        [bundles addObject:libraryBundle];
    }

    if ([NSBundle mainBundle] && ![bundles containsObject:[NSBundle mainBundle]]) {
        [bundles addObject:[NSBundle mainBundle]];
    }

    for (NSBundle * bundle in bundles)
    {
        NSError * error = nil;
        id<MTLLibrary> library = nil;

        @try {
            library = [device newDefaultLibraryWithBundle:bundle error:&error];
        } @catch (NSException * exception) {
            // Raised when the bundle has no default metallib at all
            library = nil;
        }

        if (library) {
            return library;
        }

        Log(@"LAUCaptureVideoPreviewLayerUtilities: No default metallib in bundle %@ (%@)", [bundle bundlePath], error);
    }

    Log(@"LAUCaptureVideoPreviewLayerUtilities: Could not load the default metallib. Make sure LAUCaptureVideoPreviewLayerShaders.metal is compiled into the target.");

    return nil;
}

#pragma mark -
#pragma mark Render pipeline state

id<MTLRenderPipelineState> loadRenderPipelineState(id<MTLDevice> device, id<MTLLibrary> library, NSString * vertexFunctionName, NSString * fragmentFunctionName, MTLPixelFormat pixelFormat, NSString * label)
{
    id<MTLFunction> vertexFunction = [library newFunctionWithName:vertexFunctionName];
    id<MTLFunction> fragmentFunction = [library newFunctionWithName:fragmentFunctionName];

    if (!vertexFunction || !fragmentFunction)
    {
        Log(@"LAUCaptureVideoPreviewLayerUtilities: Could not find the shader functions %@ and %@", vertexFunctionName, fragmentFunctionName);
        return nil;
    }

    MTLRenderPipelineDescriptor * renderPipelineDescriptor = [MTLRenderPipelineDescriptor new];
    renderPipelineDescriptor.label = label;
    renderPipelineDescriptor.vertexFunction = vertexFunction;
    renderPipelineDescriptor.fragmentFunction = fragmentFunction;
    renderPipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat;

    NSError * error = nil;
    id<MTLRenderPipelineState> renderPipelineState = [device newRenderPipelineStateWithDescriptor:renderPipelineDescriptor error:&error];

    if (!renderPipelineState)
    {
        Log(@"LAUCaptureVideoPreviewLayerUtilities: Failed to create the render pipeline state %@ (%@)", label, error);
    }

    return renderPipelineState;
}

#pragma mark -
#pragma mark Sampler state

id<MTLSamplerState> loadSamplerState(id<MTLDevice> device)
{
    MTLSamplerDescriptor * samplerDescriptor = [MTLSamplerDescriptor new];
    samplerDescriptor.label = @"LAUCaptureVideoPreviewLayer Sampler";
    samplerDescriptor.minFilter = MTLSamplerMinMagFilterLinear;
    samplerDescriptor.magFilter = MTLSamplerMinMagFilterLinear;
    samplerDescriptor.sAddressMode = MTLSamplerAddressModeClampToEdge;
    samplerDescriptor.tAddressMode = MTLSamplerAddressModeClampToEdge;

    return [device newSamplerStateWithDescriptor:samplerDescriptor];
}

#pragma mark -
#pragma mark Render target

id<MTLTexture> loadRenderTargetTexture(id<MTLDevice> device, NSUInteger width, NSUInteger height, MTLPixelFormat pixelFormat, MTLStorageMode storageMode)
{
    MTLTextureDescriptor * textureDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:pixelFormat width:MAX((NSUInteger)1, width) height:MAX((NSUInteger)1, height) mipmapped:NO];
    textureDescriptor.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
    textureDescriptor.storageMode = storageMode;

    id<MTLTexture> texture = [device newTextureWithDescriptor:textureDescriptor];

    if (!texture)
    {
        Log(@"LAUCaptureVideoPreviewLayerUtilities: Failed to create a %lux%lu render target texture", (unsigned long)width, (unsigned long)height);
    }

    return texture;
}

MTLRenderPassDescriptor * loadRenderPassDescriptor(id<MTLTexture> texture)
{
    MTLRenderPassDescriptor * renderPassDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
    renderPassDescriptor.colorAttachments[0].texture = texture;
    // Clear rather than MTLLoadActionDontCare: the pass is expected to cover the whole
    // render target, but a target that is only partially rasterized would otherwise
    // expose uninitialized memory, which the next filter pass would sample and spread
    renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
    renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;

    return renderPassDescriptor;
}

#pragma mark -
#pragma mark Texture instance

@implementation LAUTextureInstance
@end
