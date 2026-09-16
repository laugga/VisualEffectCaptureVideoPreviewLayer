/*

 LAUCaptureVideoPreviewLayerLogging.h
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

#ifndef LAUCaptureVideoPreviewLayerLogging_h
#define LAUCaptureVideoPreviewLayerLogging_h

#warning "Objective-C — needs to be refactored and re-written in Swift"

#import <Foundation/Foundation.h>

/*
 These used to live in support/LAUCaptureVideoPreviewLayer-Prefix.pch, which was
 applied to every source file of the CocoaPods target. Swift Package Manager has
 no prefix header, so the macros are declared here and imported where needed.
 */

#ifdef DEBUG
#define Log(format, ...) NSLog(@"%@",[NSString stringWithFormat:format, ## __VA_ARGS__])
#define Logc(format, ...) printf((format "\n"), ## __VA_ARGS__)
#define PrettyLog NSLog(@"%s", __PRETTY_FUNCTION__)
#define PrettyLogc printf("%s\n", __PRETTY_FUNCTION__)
#else
#define Log(format, ...)
#define Logc(format, ...)
#define PrettyLog
#define PrettyLogc
#endif

#endif /* LAUCaptureVideoPreviewLayerLogging_h */
