/*

 LAUCaptureVideoPreviewLayerUtilities.h
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

#ifndef LAUCaptureVideoPreviewLayerUtilities_h
#define LAUCaptureVideoPreviewLayerUtilities_h

#import <Metal/Metal.h>

// Library loading
id<MTLLibrary> loadLibrary(id<MTLDevice> device);

// Render pipeline state, the Metal equivalent of a linked glsl program
id<MTLRenderPipelineState> loadRenderPipelineState(id<MTLDevice> device, id<MTLLibrary> library, NSString * vertexFunctionName, NSString * fragmentFunctionName, MTLPixelFormat pixelFormat, NSString * label);

// Sampler state, the Metal equivalent of the GL_TEXTURE_2D texture parameters
id<MTLSamplerState> loadSamplerState(id<MTLDevice> device);

// Render target texture, the Metal equivalent of a texture-backed framebuffer
id<MTLTexture> loadRenderTargetTexture(id<MTLDevice> device, NSUInteger width, NSUInteger height, MTLPixelFormat pixelFormat, MTLStorageMode storageMode);

// Render pass descriptor for drawing into a render target texture
MTLRenderPassDescriptor * loadRenderPassDescriptor(id<MTLTexture> texture);

#endif /* LAUCaptureVideoPreviewLayerUtilities_h */
