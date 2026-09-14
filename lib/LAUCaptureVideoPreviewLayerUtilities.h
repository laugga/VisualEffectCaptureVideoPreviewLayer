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

#warning "Objective-C — needs to be refactored and re-written in Swift"

#if TARGET_OS_IPHONE
    #import <OpenGLES/ES2/gl.h>
#else
    #import <OpenGL/gl.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

struct Shader {
    GLchar * string;
	GLsizei byteSize;
	GLenum shaderType; // Vertex or Fragment
};
    
typedef struct Shader Shader_t;

// Shader memory management
Shader_t * allocShader(GLenum shaderType, const char * shaderSource);
void freeShader(Shader_t * shader);
    
// Shader compilation
GLuint buildShader(const char * source, GLenum shaderType);
GLuint buildProgram(const char * vertexShaderSource, const char * fragmentShaderSource);
int validateProgram(GLuint programHandle);
    
// Shader loading
GLuint loadProgram(const char * vertexShaderSource, const char * fragmentShaderSource);
void unloadProgram(GLuint * programHandle);

// Framebuffer status
bool checkFramebufferStatusComplete(void);
    
#ifdef __cplusplus
}
#endif

#endif /* LAUCaptureVideoPreviewLayerUtilities_h */
