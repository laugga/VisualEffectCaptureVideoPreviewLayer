# AGENTS.md

## What this is

**`LAUCaptureVideoPreviewLayer`** is a preview layer for an `AVCaptureSession`
with a GPU blur filter — a near-drop-in replacement for AVFoundation's
`AVCaptureVideoPreviewLayer` that adds one animatable `blur` property in
`[0,1]`. It is a `CAMetalLayer` subclass; the blur is a separable Gaussian
written in the Metal Shading Language.

It does not sit in the capture session the way Apple's layer does. It adds an
`AVCaptureVideoDataOutput` to the session you hand it, and renders each frame
from `captureOutput(_:didOutput:from:)`. If the session already has an
`AVCaptureVideoDataOutput`, it hijacks that one and forwards the delegate
callback on to you.

**Swift, Metal and Swift Package Manager.** The library, the tests and the
example are Swift. The only non-Swift sources are the `.metal` shaders and the
one C header whose structures both Swift and the shaders read — see
[Project layout](#project-layout). There is no CocoaPods, no podspec, no
Rakefile and no library xcodeproj any more; `Package.swift` is the build.

**Nothing depends on this component today.** It is a standalone Lightmate
component, not a dependency of any repository in the organisation:
`lightmate-app-ios` uses Apple's own `AVCaptureVideoPreviewLayer`, and no other
laugga repository references this one. The only release is the `0.1.0` tag,
the old OpenGL ES CocoaPod, which predates the package entirely. Treat the
public API as unpublished: no consumer is pinned to it.

It is, in the author's own words in the README, an R&D project.

## Build and test

Run from the repository root:

```bash
# Build and run the 4 tests
xcodebuild test -scheme LAUCaptureVideoPreviewLayer \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)'

# Build the example app
xcodebuild build \
  -project examples/LAUCaptureVideoPreviewLayerExample/LAUCaptureVideoPreviewLayerExample.xcodeproj \
  -scheme LAUCaptureVideoPreviewLayerExample \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)'
```

These are the same two steps `.github/workflows/ci.yml` runs on every pull
request (`Build and test`). If the simulator name is ambiguous because it is
installed for more than one runtime, use `id=<udid>` from
`xcrun simctl list devices available` instead of `name=`.

**`swift build` and `swift test` do not work.** The package is iOS-only and
needs UIKit, AVFoundation and a Metal device, so it has to go through
`xcodebuild` with an iOS Simulator destination.

**Use a 2x simulator, such as the iPhone SE.** Two of the four tests compare
the rendered blur against reference PNGs captured at a 2x scale, and they
`XCTSkipUnless(UIScreen.main.nativeScale == 2)`. On an iPhone 15 or 17 (3x)
they are *skipped*, not failed, so a green run there tests almost nothing. All
four pass on an iPhone SE.

**The Metal toolchain can be missing.** Recent Xcode versions ship it as a
separate component, and without it the `.metal` sources do not compile. CI
downloads it with `xcodebuild -downloadComponent MetalToolchain`; do the same
locally if the build fails on the shaders.

**There is no lint step and no `Makefile`.** No SwiftLint, no swift-format. The
commands above are the whole gate. With no root `deploy` target, there is no
try-it build for this repository either.

## Run the example app

`examples/LAUCaptureVideoPreviewLayerExample/` is a single-view app — a capture
session, a back camera, tap to blur in, pull down to blur out — and it is the
only place the layer is exercised on screen. Its xcodeproj references the
package at the repository root as a local package (`../..`), so there is
nothing to install; open the project and run.

The Simulator has no camera. Under `#if targetEnvironment(simulator)` the
example swaps in `MockCaptureVideoPreviewLayerInternal`, which feeds the layer a
generated colour grid, so the on-screen path can still be checked there. The
real camera path only runs on a device.

## Project layout

| Path | What's there |
|---|---|
| `Package.swift` | The build. Two targets and a test target, iOS 17.0. |
| `Sources/LAUCaptureVideoPreviewLayer/` | The library. `LAUCaptureVideoPreviewLayer.swift` is the layer and the render pipeline; `…Internal.swift` owns the capture session and the sample buffer; `…Utilities.swift` has `TextureInstance`, metallib loading and pipeline state creation; `…Shaders.swift` holds the shader function names; `…GaussianFilterKernel.swift` the kernel tables. |
| `Sources/LAUCaptureVideoPreviewLayer/LAUCaptureVideoPreviewLayerShaders.metal` | The shaders, compiled at build time into the target's default metallib. |
| `Sources/LAUCaptureVideoPreviewLayerShaderTypes/` | A C target whose only job is `include/LAUCaptureVideoPreviewLayerStructures.h`: the buffer indices, `VertexData_t` and `FilterUniforms_t`, read by both Swift and the `.metal` file. The `.c` file is empty on purpose — SwiftPM will not build a target without a compilation unit. |
| `Tests/LAUCaptureVideoPreviewLayerTests/` | The 4 tests, the `UIImage` comparison helper, a mock pipeline and `Samples.xcassets` with the source and reference images. |
| `examples/LAUCaptureVideoPreviewLayerExample/` | The example app. |
| `docs/` | `features.md`, `figures/` (the README's GIF) and `matlab/` — the MATLAB script that generates the filter kernels, plus its plots. |
| `CHANGELOG.md` | Human-written; the Metal, Swift and SPM changes sit under `Unreleased`. |

## Conventions

Branch names, pull request titles and bodies, and how a pull request references
its task are the same in every Laugga Practice repository and are documented in
[`laugga/ops`](https://github.com/laugga/ops). What is specific here:

- **The default and integration branch is `main`.** Open pull requests against
  it.
- **Every type carries the `LAU` prefix; the repository does not.** The
  repository is `VisualEffectCaptureVideoPreviewLayer`, the class is
  `LAUCaptureVideoPreviewLayer`, and the mismatch is deliberate and settled.
  Keep public types on `LAU`; do not rename toward the repository name.
- **Every file under `Sources/` opens with the MIT-style license header block**
  carrying the file name and `LAUCaptureVideoPreviewLayer`. Copy it into new
  files.
- **Document with `///`**, and keep the public surface small. What is public is
  what is implemented: `init(session:)`, `session`, `blur`,
  `setBlur(_:animated:)` and `videoGravity`. Do not add stubs that only mirror
  `AVCaptureVideoPreviewLayer`'s interface.
- **Log through the module's `log`** (`os.Logger`, in `…Utilities.swift`), not
  `print`.
- **Anything both Swift and the shaders read goes in
  `LAUCaptureVideoPreviewLayerStructures.h`**, and must be valid in both C and
  the Metal Shading Language. Do not duplicate a layout as a Swift struct: the
  shared header is what guarantees the two sides agree.

## Gotchas

- **The metallib is looked up in `Bundle.module`, then `Bundle.main`.** SwiftPM
  compiles the `.metal` file into the resource bundle it generates for the
  target. If the layer draws nothing, check the log for `Could not load the
  default metallib` before suspecting the rendering code.

- **The offscreen quads flip the texture coordinates vertically, on purpose.**
  Metal draws a texture's first row at the top of the viewport, so the flip is
  what keeps every offscreen pass an exact copy of its source. And
  `render(in:)` flips the context, because `getBytes` returns rows top-down.
  Removing either "fix" turns the image upside down on alternate passes or in
  snapshots.

- **Round offscreen texture sizes to whole pixels, and clear them.** A
  fractional size left the last pixel column unrasterized, and clamp-to-edge
  sampling smeared that uninitialised memory into the blur. It showed up as two
  renders of the same frame differing by about 2%.

- **The blur implementation is selected by two flags at the top of
  `LAUCaptureVideoPreviewLayer.swift`.** `filterBoundsEnabled = false` and
  `filterBilinearTextureSamplingEnabled = true` choose which of three fragment
  functions the blur pipeline uses. At these settings the other two are
  unreachable. Behaviour you cannot reproduce may be behind a flag that is off.

- **The kernel tables are generated.** `…GaussianFilterKernel.swift` holds the
  output of `docs/matlab/LAUCaptureVideoPreviewLayer.m`. Regenerate rather than
  hand-edit, and keep `kFilterKernelMaxSamples` and `kFilterKernelMaxWeights` in
  the shared header large enough for them.

- **The tests reach into internal API.** They inject
  `MockLAUCaptureVideoPreviewLayerInternal` through the public `internal`
  property and call `drawPixelBuffer()` through `@testable import`. Changing
  either breaks the tests although neither is API anyone was meant to use. The
  example has its own, similar stand-in in
  `MockCaptureVideoPreviewLayerInternal.swift`; update both.

- **The `CADisplayLink` retains its target**, so a layer never deallocates and
  its textures leak if preview layers are created repeatedly. Known, not yet
  fixed.

- **The example's bundle identifier is still `co.coletiv.*`**, a former
  organisation. Leave it unless that is the task.

- **`docs/matlab/LAUCaptureVideoPreviewLayer` is a Photoshop file with no
  extension**, sitting next to the `.m` script of the same name. Not a
  directory, not MATLAB. Leave it alone.

## Definition of done

Before opening a pull request, confirm:

- [ ] `xcodebuild test -scheme LAUCaptureVideoPreviewLayer -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)'` runs 4 tests with 0 failures and 0 skipped
- [ ] The example builds with the command above
- [ ] If a structure shared with the shaders changed, it changed in `LAUCaptureVideoPreviewLayerStructures.h`, not in a Swift copy
- [ ] `CHANGELOG.md` has an `Unreleased` line if a user of the package would notice the change
