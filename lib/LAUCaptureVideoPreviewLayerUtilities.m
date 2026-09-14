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

#include "LAUCaptureVideoPreviewLayerUtilities.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#pragma mark - 
#pragma mark Shader Memory Management

Shader_t * allocShader(GLenum shaderType, const char * shaderSource)
{
    Shader_t * shader = (Shader_t *)calloc(sizeof(Shader_t), 1);
    shader->shaderType = shaderType;
	
    // Get the size of the source
	GLsizei sourceLength = (GLsizei)strlen(shaderSource);
	
	// Add 1 to the file size to include the null terminator for th string
    shader->byteSize = sourceLength + 1;
	
	// Alloc memory for the string
	shader->string = (GLchar*)malloc(shader->byteSize);
	
	// Copy the entire string
    strcpy(shader->string, shaderSource);
    
	// Insert null terminator
	shader->string[sourceLength] = 0;
	
	return shader;
}

void freeShader(Shader_t * shader)
{
    // Release dynamic memory allocated for string and the shader itself
	free(shader->string);
	free(shader);
}

#pragma mark -
#pragma mark Shader Compilation

GLuint buildShader(const char * source, GLenum shaderType)
{
    GLint logLength, compileStatus;
    
    // Create shader
    GLuint shaderHandle = glCreateShader(shaderType);
    glShaderSource(shaderHandle, 1, &source, 0);   
    
    // Compile shader
    glCompileShader(shaderHandle);
    glGetShaderiv(shaderHandle, GL_INFO_LOG_LENGTH, &logLength);
	if (logLength > 0) 
	{
		GLchar *log = (GLchar*)malloc(logLength);
		glGetShaderInfoLog(shaderHandle, logLength, &logLength, log);
		Logc("Shader compile log:\n%s", log);
		free(log);
	}
    
    glGetShaderiv(shaderHandle, GL_COMPILE_STATUS, &compileStatus);
    if (compileStatus == GL_FALSE) {
        GLchar messages[256];
        glGetShaderInfoLog(shaderHandle, sizeof(messages), 0, &messages[0]);
        Logc("Shader failed to compile:\n%s", messages);
        exit(1);
    }
    
    return shaderHandle;
}

GLuint buildProgram(const char * vertexShaderSource, const char * fragmentShaderSource)
{
    GLint logLength, linkStatus;
    
    // Compile fragment and vertex shader
    GLuint vertexShader = buildShader(vertexShaderSource, GL_VERTEX_SHADER);
    GLuint fragmentShader = buildShader(fragmentShaderSource, GL_FRAGMENT_SHADER);
    
    // Create program
    GLuint programHandle = glCreateProgram();
    
    // Attach compiled shaders
    glAttachShader(programHandle, vertexShader);
    glDeleteShader(vertexShader); // Flag for deletion
    glAttachShader(programHandle, fragmentShader);
    glDeleteShader(fragmentShader); // Flag for deletion
    
    // Link program
    glLinkProgram(programHandle);
    glGetProgramiv(programHandle, GL_INFO_LOG_LENGTH, &logLength);
	if (logLength > 0)
	{
		GLchar *log = (GLchar*)malloc(logLength);
		glGetProgramInfoLog(programHandle, logLength, &logLength, log);
		Logc("Program link log:\n%s", log);
		free(log);
	}
    
    glGetProgramiv(programHandle, GL_LINK_STATUS, &linkStatus);
    if (linkStatus == GL_FALSE) {
        GLchar messages[256];
        glGetProgramInfoLog(programHandle, sizeof(messages), 0, &messages[0]);
        Logc("Failed to link program:\n%s", messages);
        exit(1);
    }
    
    return programHandle;
}

int validateProgram(GLuint programHandle)
{
    GLint logLength, validateStatus;
    
    // Validate program
    glValidateProgram(programHandle);
    glGetProgramiv(programHandle, GL_INFO_LOG_LENGTH, &logLength);
	if (logLength > 0)
	{
		GLchar *log = (GLchar*)malloc(logLength);
		glGetProgramInfoLog(programHandle, logLength, &logLength, log);
		Logc("Program validate log:\n%s", log);
		free(log);
	}
    
    glGetProgramiv(programHandle, GL_VALIDATE_STATUS, &validateStatus);
	if (validateStatus == GL_FALSE)
	{
        GLchar messages[256];
        glGetProgramInfoLog(programHandle, sizeof(messages), 0, &messages[0]);
        Logc("Failed to validate program:\n%s", messages);
        exit(1);
	}
    
    return 0;
}

#pragma mark -
#pragma mark Loading

GLuint loadProgram(const char * vertexShaderSource, const char * fragmentShaderSource)
{
    // Program handle
    GLuint programHandle;
    
    // Load shaders
    Shader_t * vertexShader = allocShader(GL_VERTEX_SHADER, vertexShaderSource);
    Shader_t * fragmentShader = allocShader(GL_FRAGMENT_SHADER, fragmentShaderSource);
    
    // Create the GLSL program.
    programHandle = buildProgram(vertexShader->string, fragmentShader->string);
    
    // Unload shaders
    freeShader(vertexShader);
    freeShader(fragmentShader);
    
    return programHandle;
}

void unloadProgram(GLuint * programHandle)
{
    if (*programHandle) 
    {
        glDeleteProgram(*programHandle); // Delete program - shaders have been flagged after attaching and so will be deleted as well
        *programHandle = 0;
    }
}

#pragma mark -
#pragma mark Framebuffer

// Checks current bound framebuffer status
bool checkFramebufferStatusComplete(void)
{
    GLenum framebufferStatus = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    
    switch (framebufferStatus) {
        case GL_FRAMEBUFFER_COMPLETE:
            return true; // We can return true
            break;
        case GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT:
            Logc("Framebuffer Status Error: Incomplete Attachment Point");
            break;
        case GL_FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT:
            Logc("Framebuffer Status Error: Missing Attachment");
            break;
#if TARGET_OS_MAC && !TARGET_OS_IPHONE // NOT OPEN GL ES
        case GL_FRAMEBUFFER_INCOMPLETE_DIMENSIONS_EXT:
            Logc("Framebuffer Status Error: Dimensions do not match");
            break;
        case GL_FRAMEBUFFER_INCOMPLETE_FORMATS_EXT:
            Logc("Framebuffer Status Error: Formats");
            break;
        case GL_FRAMEBUFFER_INCOMPLETE_DRAW_BUFFER:
            Logc("Framebuffer Status Error: Draw Buffer");
            break;
        case GL_FRAMEBUFFER_INCOMPLETE_READ_BUFFER:
            Logc("Framebuffer Status Error: Read Buffer");
            break;
#endif
        case GL_FRAMEBUFFER_UNSUPPORTED:
            Logc("Framebuffer Status Error: Unsupported Framebuffer Configuration");
            break;
        default:
            Logc("Framebuffer Status Error: Unkown Framebuffer Object Failure");
            break;
    }
    
    return false;
}

