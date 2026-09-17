## Unreleased

* Renamed every public type and file from the `LAU` prefix to `LM` (e.g. `LAUCaptureVideoPreviewLayer` → `LMCaptureVideoPreviewLayer`); no consumer was pinned to the old name
* Metal based implementation, replacing OpenGL ES 2.0
* Written in Swift
* Distributed with Swift Package Manager, CocoaPods support removed
* Minimum deployment target raised to iOS 17.0
* Only the implemented part of the AVCaptureVideoPreviewLayer interface is exposed
* The layer reacts to its session starting and stopping on the main queue, whichever thread started or stopped it

## 0.1.0

* OpenGL ES 2.0 based implementation
