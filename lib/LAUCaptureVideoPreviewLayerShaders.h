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

#warning "Objective-C — needs to be refactored and re-written in Swift"

/*!
 Vertex Shader
 
 Implementation:
 - Filter is disabled
 */
static const char * VertexShaderSourceDefault =
{
    "// (In) Vertex attributes\n"
    "attribute vec4 VertPosition;\n"
    "attribute vec2 VertTextureCoordinate;\n"
    "\n"
    "// (Out) Fragment variables\n"
    "varying vec2 FragTextureCoordinate;\n"
    "\n"
    "void main()\n"
    "{\n"
    "  FragTextureCoordinate = VertTextureCoordinate.xy;\n"
    "  gl_Position = VertPosition;\n"
    "}\n"
};

/*!
 Fragment Shader
 
 Implementation:
 - Filter is disabled
 */
static const char * FragmentShaderSourceDefault =
{
    "#ifdef GL_ES\n"
    "precision highp float;\n"
    "#endif\n"
    "\n"
    "// (In) Texture coordinate for the fragment\n"
    "varying vec2 FragTextureCoordinate;\n"
    "\n"
    "// Uniforms (VideoFrame)\n"
    "uniform sampler2D FragTextureData;\n"
    "\n"
    "void main()\n"
    "{\n"
    "  gl_FragColor = texture2D(FragTextureData, FragTextureCoordinate);\n"
    "}\n"
};

/*!
 Vertex Shader
 
 Implementation:
 - Filter is enabled
 - Bilinear texture sampling enabled
 - Filter bounds disabled
 */
static const char * VertexShaderSourceBlurFilterBts =
{
    "// (In) Vertex attributes\n"
    "attribute vec4 VertPosition;\n"
    "attribute vec2 VertTextureCoordinate;\n"
    "\n"
    "// (In) Vertex uniforms (shared)\n"
    "uniform lowp int   FilterKernelSamples;\n"
    "uniform highp vec2 FilterSplitPassDirectionVector;\n"
    "\n"
    "// (In) Vertex uniforms\n"
    "uniform float VertFilterKernelOffsets[14];\n"
    "\n"
    "// (Out) Fragment variables\n"
    "varying vec2 FragTextureCoordinate;\n"
    "varying vec2 FragFilterTextureCoordinates[8];\n"
    "varying vec2 FragFilterSplitPassKernelOffsets[6];\n"
    "\n"
    "void main()\n"
    "{\n"
    "  // Sample with the provided weights and offsets in one direction\n"
    "  // Unrolled for loop. Constant FilterKernelSamples = 10.\n"
    "\n"
    "  // Pre-calculated texture coordinates\n"
    "  FragFilterTextureCoordinates[0] = VertTextureCoordinate - (VertFilterKernelOffsets[0]*FilterSplitPassDirectionVector);\n"
    "  FragFilterTextureCoordinates[1] = VertTextureCoordinate + (VertFilterKernelOffsets[0]*FilterSplitPassDirectionVector);\n"
    "  FragFilterTextureCoordinates[2] = VertTextureCoordinate - (VertFilterKernelOffsets[1]*FilterSplitPassDirectionVector);\n"
    "  FragFilterTextureCoordinates[3] = VertTextureCoordinate + (VertFilterKernelOffsets[1]*FilterSplitPassDirectionVector);\n"
    "  FragFilterTextureCoordinates[4] = VertTextureCoordinate - (VertFilterKernelOffsets[2]*FilterSplitPassDirectionVector);\n"
    "  FragFilterTextureCoordinates[5] = VertTextureCoordinate + (VertFilterKernelOffsets[2]*FilterSplitPassDirectionVector);\n"
    "  FragFilterTextureCoordinates[6] = VertTextureCoordinate - (VertFilterKernelOffsets[3]*FilterSplitPassDirectionVector);\n"
    "  FragFilterTextureCoordinates[7] = VertTextureCoordinate + (VertFilterKernelOffsets[3]*FilterSplitPassDirectionVector);\n"
    "\n"
    "  // Pre-calculated offsets\n"
    "  // Limit is 32 varying floats, it's no possible to pre-calculate all texture coordinates\n"
    "  FragFilterSplitPassKernelOffsets[0] = VertFilterKernelOffsets[4]*FilterSplitPassDirectionVector;\n"
    "  FragFilterSplitPassKernelOffsets[1] = VertFilterKernelOffsets[5]*FilterSplitPassDirectionVector;\n"
    "  FragFilterSplitPassKernelOffsets[2] = VertFilterKernelOffsets[6]*FilterSplitPassDirectionVector;\n"
    "  FragFilterSplitPassKernelOffsets[3] = VertFilterKernelOffsets[7]*FilterSplitPassDirectionVector;\n"
    "  FragFilterSplitPassKernelOffsets[4] = VertFilterKernelOffsets[8]*FilterSplitPassDirectionVector;\n"
    "  FragFilterSplitPassKernelOffsets[5] = VertFilterKernelOffsets[9]*FilterSplitPassDirectionVector;\n"
    "\n"
    "  FragTextureCoordinate = VertTextureCoordinate;\n"
    "  gl_Position = VertPosition;\n"
    "}\n"
};

/*!
 Fragment Shader
 
 Implementation:
 - Filter is enabled
 - Bilinear texture sampling enabled
 - Filter bounds disabled
 */
static const char * FragmentShaderSourceBlurFilterBts =
{
    "#ifdef GL_ES\n"
    "precision highp float;\n"
    "#endif\n"
    "\n"
    "// Texture coordinate for the fragment\n"
    "varying vec2 FragTextureCoordinate;\n"
    "varying vec2 FragFilterTextureCoordinates[8];\n"
    "varying vec2 FragFilterSplitPassKernelOffsets[6];\n"
    "\n"
    "// Uniforms (VideoFrame)\n"
    "uniform sampler2D FragTextureData;\n"
    "\n"
    "// Uniforms (Filter)\n"
    "uniform lowp int FilterKernelSamples; // Samples per pixel\n"
    "uniform vec4 FragFilterBounds; // Bounds = { xMin, yMin, xMax, yMax }\n"
    "uniform float FragFilterKernelWeights[14]; // Weights\n"
    "\n"
    "void main()\n"
    "{\n"
    "  // Weighted color sum of all the neighbour pixel\n"
    "  vec4 weightedColor = vec4(0.0);\n"
    "\n"
    "  // Unrolled for loop. Constant FilterKernelSamples = 10.\n"
    "  // Sample with the provided weights and offsets in one direction\n"
    "\n"
    "  float weight = FragFilterKernelWeights[0];\n"
    "  weightedColor += weight * texture2D(FragTextureData, FragFilterTextureCoordinates[0]);\n"
    "  weightedColor += weight * texture2D(FragTextureData, FragFilterTextureCoordinates[1]);\n"
    "  weight = FragFilterKernelWeights[1];\n"
    "  weightedColor += weight * texture2D(FragTextureData, FragFilterTextureCoordinates[2]);\n"
    "  weightedColor += weight * texture2D(FragTextureData, FragFilterTextureCoordinates[3]);\n"
    "  weight = FragFilterKernelWeights[2];\n"
    "  weightedColor += weight * texture2D(FragTextureData, FragFilterTextureCoordinates[4]);\n"
    "  weightedColor += weight * texture2D(FragTextureData, FragFilterTextureCoordinates[5]);\n"
    "  weight = FragFilterKernelWeights[3];\n"
    "  weightedColor += weight * texture2D(FragTextureData, FragFilterTextureCoordinates[6]);\n"
    "  weightedColor += weight * texture2D(FragTextureData, FragFilterTextureCoordinates[7]);\n"
    "\n"
    "  weight = FragFilterKernelWeights[4];\n"
    "  vec2 offset = FragFilterSplitPassKernelOffsets[0];\n"
    "  weightedColor += weight * texture2D(FragTextureData, FragTextureCoordinate - offset);\n"
    "  weightedColor += weight * texture2D(FragTextureData, FragTextureCoordinate + offset);\n"
    "  weight = FragFilterKernelWeights[5];\n"
    "  offset = FragFilterSplitPassKernelOffsets[1];\n"
    "  weightedColor += weight * texture2D(FragTextureData, FragTextureCoordinate - offset);\n"
    "  weightedColor += weight * texture2D(FragTextureData, FragTextureCoordinate + offset);\n"
    "  weight = FragFilterKernelWeights[6];\n"
    "  offset = FragFilterSplitPassKernelOffsets[2];\n"
    "  weightedColor += weight * texture2D(FragTextureData, FragTextureCoordinate - offset);\n"
    "  weightedColor += weight * texture2D(FragTextureData, FragTextureCoordinate + offset);\n"
    "  weight = FragFilterKernelWeights[7];\n"
    "  offset = FragFilterSplitPassKernelOffsets[3];\n"
    "  weightedColor += weight * texture2D(FragTextureData, FragTextureCoordinate - offset);\n"
    "  weightedColor += weight * texture2D(FragTextureData, FragTextureCoordinate + offset);\n"
    "  weight = FragFilterKernelWeights[8];\n"
    "  offset = FragFilterSplitPassKernelOffsets[4];\n"
    "  weightedColor += weight * texture2D(FragTextureData, FragTextureCoordinate - offset);\n"
    "  weightedColor += weight * texture2D(FragTextureData, FragTextureCoordinate + offset);\n"
    "  weight = FragFilterKernelWeights[9];\n"
    "  offset = FragFilterSplitPassKernelOffsets[5];\n"
    "  weightedColor += weight * texture2D(FragTextureData, FragTextureCoordinate - offset);\n"
    "  weightedColor += weight * texture2D(FragTextureData, FragTextureCoordinate + offset);\n"
    "\n"
    "  gl_FragColor = weightedColor;\n"
    "}\n"
};

/*!
 Fragment Shader
 
 Implementation:
 - Filter is enabled
 - Bilinear texture sampling enabled
 - Filter bounds enabled
 */
static const char * FragmentShaderSourceBlurFilterBtsBounds =
{
    "#ifdef GL_ES\n"
    "precision highp float;\n"
    "#endif\n"
    "\n"
    "// Texture coordinate for the fragment\n"
    "varying vec2 FragTextureCoordinate;\n"
    "varying vec2 FragFilterSplitPassKernelOffsets[14];\n"
    "\n"
    "// Uniforms (VideoFrame)\n"
    "uniform sampler2D FragTextureData;\n"
    "\n"
    "// Uniforms (Filter)\n"
    "uniform lowp int FilterKernelSamples; // Samples per pixel\n"
    "uniform vec4 FragFilterBounds; // Bounds = { xMin, yMin, xMax, yMax }\n"
    "uniform float FragFilterKernelWeights[14]; // Weights\n"
    "\n"
    "void main()\n"
    "{\n"
    "  if (FragTextureCoordinate.x < FragFilterBounds.x ||\n"
    "      FragTextureCoordinate.y < FragFilterBounds.y ||\n"
    "      FragTextureCoordinate.x > FragFilterBounds.z ||\n"
    "      FragTextureCoordinate.y > FragFilterBounds.w)\n"
    "  {\n"
    "    gl_FragColor = texture2D(FragTextureData, FragTextureCoordinate);\n"
    "  }\n"
    "  else\n"
    "  {\n"
    "    // Weighted color sum of all the neighbour pixel\n"
    "    vec4 weightedColor = vec4(0.0);\n"
    "\n"
    "    // Sample with the provided weights and offsets in one direction\n"
    "    for (int s = 0; s < FilterKernelSamples; ++s)\n"
    "    {\n"
    "      float weight = FragFilterKernelWeights[s];\n"
    "      vec2 offset = FragFilterSplitPassKernelOffsets[s];\n"
    "      weightedColor += weight * texture2D(FragTextureData, FragTextureCoordinate.xy - offset) +\n"
    "                       weight * texture2D(FragTextureData, FragTextureCoordinate.xy + offset);\n"
    "    }\n"
    "\n"
    "    gl_FragColor = weightedColor;\n"
    "  }\n"
    "}\n"
};

/*!
 Fragment Shader
 
 Implementation:
 - Discrete Texture Sampling
 - Bounds disabled
 */
static const char * FragmentShaderSourceBlurFilterDts =
{
    "#ifdef GL_ES\n"
    "precision highp float;\n"
    "#endif\n"
    "\n"
    "// (In) Texture coordinate for the fragment\n"
    "varying vec2 FragTextureCoordinate;\n"
    "\n"
    "// Uniforms (VideoFrame)\n"
    "uniform sampler2D FragTextureData;\n"
    "\n"
    "// Uniforms (Filter)\n"
    "uniform int FragFilterKernelSize; // Size = N\n"
    "uniform int FragFilterKernelRadius; // Radius = N - 1\n"
    "uniform float FragFilterKernelWeights[50]; // 1D convolution kernel\n"
    "uniform vec2 FilterSplitPassDirectionVector; // Apply kernel in direction, x or y\n"
    "\n"
    "void main()\n"
    "{\n"
    "  // Weighted color sum of all the neighbour pixel\n"
    "  vec4 weightedColor = vec4(0.0);\n"
    "\n"
    "  // Convolve with the provided Kernel in one direction\n"
    "  for (int offset = -FragFilterKernelRadius; offset <= FragFilterKernelRadius; ++offset)\n"
    "  {\n"
    "    float weight = FragFilterKernelWeights[FragFilterKernelRadius+offset];\n"
    "    weightedColor += weight * texture2D(FragTextureData, FragTextureCoordinate.xy + (float(offset)*FilterSplitPassDirectionVector));\n"
    "  }\n"
    "\n"
    "  gl_FragColor = weightedColor;\n"
    "}\n"
};

#endif /* LAUCaptureVideoPreviewLayerShaders_h */
