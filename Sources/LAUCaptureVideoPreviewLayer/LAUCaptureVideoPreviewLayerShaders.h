/*

 LAUCaptureVideoPreviewLayerShaders.h
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

#ifndef LAUCaptureVideoPreviewLayerShaders_h
#define LAUCaptureVideoPreviewLayerShaders_h

#import <Foundation/Foundation.h>

/*
 The shader sources live in LAUCaptureVideoPreviewLayerShaders.metal and are
 compiled by Xcode into the default metallib of whatever target links the
 library. Unlike the OpenGL ES implementation, which compiled the GLSL sources
 at runtime, the only thing needed here are the names used to look the shader
 functions up in the library.
 */

#pragma mark -
#pragma mark Vertex functions

/*!
 Vertex Shader

 Implementation:
 - Passthrough, shared by every render pipeline
 */
static NSString * const VertexShaderNameDefault = @"defaultVertexShader";

#pragma mark -
#pragma mark Fragment functions

/*!
 Fragment Shader

 Implementation:
 - Filter is disabled
 */
static NSString * const FragmentShaderNameDefault = @"defaultFragmentShader";

/*!
 Fragment Shader

 Implementation:
 - Filter is enabled
 - Bilinear texture sampling enabled
 - Filter bounds disabled
 */
static NSString * const FragmentShaderNameBlurFilterBts = @"blurFilterBtsFragmentShader";

/*!
 Fragment Shader

 Implementation:
 - Filter is enabled
 - Bilinear texture sampling enabled
 - Filter bounds enabled
 */
static NSString * const FragmentShaderNameBlurFilterBtsBounds = @"blurFilterBtsBoundsFragmentShader";

/*!
 Fragment Shader

 Implementation:
 - Discrete Texture Sampling
 - Bounds disabled
 */
static NSString * const FragmentShaderNameBlurFilterDts = @"blurFilterDtsFragmentShader";

#endif /* LAUCaptureVideoPreviewLayerShaders_h */
