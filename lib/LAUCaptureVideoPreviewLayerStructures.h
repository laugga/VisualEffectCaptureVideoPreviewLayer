/*
 
 LAUCaptureVideoPreviewLayerStructures.h
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

#ifndef LAUCaptureVideoPreviewLayerStructures_h
#define LAUCaptureVideoPreviewLayerStructures_h

#warning "Objective-C — needs to be refactored and re-written in Swift"

#pragma mark -
#pragma Shader handles

struct UniformHandles {
    
    GLuint FragTextureData;
    
    GLuint FilterSplitPassDirectionVector; // vec2 (x or y step direction)
    
    GLuint FragFilterBounds; // vec4
    
    GLuint VertFilterKernelOffsets; // float[]
    
    GLuint FragFilterKernelWeights; // float[]
    GLuint FragFilterKernelRadius; // float
    GLuint FragFilterKernelSize; // float
    
    GLuint FilterKernelSamples; // float
};

struct AttributeHandles {
    GLuint VertPosition;
    GLuint VertTextureCoordinate;
};

struct FilterKernel {
    GLuint radius;
    GLfloat * weights;
    GLuint samples; // s
    GLfloat * offsets;
    GLuint size; // m
};

typedef struct FilterKernel FilterKernel_t;

typedef struct {
    GLfloat position[2];
    GLfloat textureCoordinate[2];
} VertexData_t;

struct TextureInstance {

    // Texture dimensions
    GLfloat textureWidth;
    GLfloat textureHeight;
    
    // Texture binding
    GLuint textureName;
    GLuint textureTarget; // ie. GL_TEXTURE_2D
    
    // Geometry, VAO for drawing quad (optional)
    // Vertex Positions and Texture coordinates (aspect-fit) (optional)
    GLuint vertexArray;
    GLuint vertexBuffer;
    GLuint vertexCount;
    
    // Geometry, primitive type such as GL_TRIANGLE_STRIP (optional)
    GLuint primitiveType;
    
    // Drawing framebuffer
    GLuint framebuffer;
};

typedef struct TextureInstance TextureInstance_t;

#endif /* LAUCaptureVideoPreviewLayerStructures_h */
